import Foundation
import Supabase

@MainActor
class AuthService: ObservableObject {
    static let shared = AuthService()

    private let supabaseURL = URL(string: "https://YOUR_PROJECT_REF.supabase.co")!
    private let supabaseKey = "REDACTED_SUPABASE_ANON_KEY"

    let supabase: SupabaseClient

    init() {
        supabase = SupabaseClient(supabaseURL: supabaseURL, supabaseKey: supabaseKey)
    }

    @Published var currentUser: User?
    @Published var currentHousehold: Household?
    @Published var householdUsers: [User] = []
    @Published var householdItems: [Item] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    // MARK: - Insert / Update Payloads (snake_case to match DB columns)

    private struct NewHousehold: Encodable {
        let name: String
        let created_by_user_id: String
    }
    private struct NewUser: Encodable {
        let household_id: String
        let name: String
        let rotation_order: Int
    }
    private struct NewItem: Encodable {
        let household_id: String
        let name: String
        let current_assignee_id: String
    }
    private struct NewJoinCode: Encodable {
        let household_id: String
        let code: String
        let expires_at: String
    }
    private struct HouseholdCreatorUpdate: Encodable {
        let created_by_user_id: String
    }
    private struct PauseUpdate: Encodable {
        let paused_until: String?
    }

    private struct JoinCodeRow: Decodable {
        let household_id: String
    }

    // MARK: - Household Setup

    /// First user creates household and becomes admin (rotation_order = 1).
    func createHouseholdAsFirstUser(name: String, householdName: String) async {
        isLoading = true
        errorMessage = nil

        do {
            // Placeholder created_by; updated to real user id once the user exists.
            let placeholderId = UUID().uuidString
            let household: Household = try await supabase
                .from("households")
                .insert(NewHousehold(name: householdName, created_by_user_id: placeholderId))
                .select()
                .single()
                .execute()
                .value

            let user: User = try await supabase
                .from("users")
                .insert(NewUser(household_id: household.id, name: name, rotation_order: 1))
                .select()
                .single()
                .execute()
                .value

            // Point household.created_by at the real user.
            try await supabase
                .from("households")
                .update(HouseholdCreatorUpdate(created_by_user_id: user.id))
                .eq("id", value: household.id)
                .execute()

            // Seed default items, all assigned to the first user.
            let defaults = ["Milk", "Eggs", "Bread", "Butter", "Coffee"]
            let newItems = defaults.map {
                NewItem(household_id: household.id, name: $0, current_assignee_id: user.id)
            }
            try await supabase.from("items").insert(newItems).execute()

            currentHousehold = household
            currentUser = user
            await fetchHouseholdData()
            isLoading = false
        } catch {
            errorMessage = "Failed to create household: \(error.localizedDescription)"
            isLoading = false
        }
    }

    /// Admin generates a 6-digit join code that expires in 7 days.
    func generateJoinCode() async -> String? {
        guard let householdId = currentHousehold?.id else { return nil }

        do {
            let code = String(format: "%06d", Int.random(in: 0..<1_000_000))
            let expiresAt = SupabaseDate.string(from: Date().addingTimeInterval(7 * 24 * 60 * 60))

            try await supabase
                .from("join_codes")
                .insert(NewJoinCode(household_id: householdId, code: code, expires_at: expiresAt))
                .execute()

            return code
        } catch {
            errorMessage = "Failed to generate join code: \(error.localizedDescription)"
            return nil
        }
    }

    /// Roommate joins a household using a code. Returns true on success.
    func joinHouseholdWithCode(name: String, code: String) async -> Bool {
        isLoading = true
        errorMessage = nil

        do {
            // Validate code (must exist and not be expired).
            let nowISO = SupabaseDate.string(from: Date())
            let matches: [JoinCodeRow] = try await supabase
                .from("join_codes")
                .select("household_id")
                .eq("code", value: code)
                .gt("expires_at", value: nowISO)
                .execute()
                .value

            guard let match = matches.first else {
                errorMessage = "Invalid or expired join code."
                isLoading = false
                return false
            }
            let householdId = match.household_id

            // Next rotation_order = current max + 1.
            let existing: [User] = try await supabase
                .from("users")
                .select()
                .eq("household_id", value: householdId)
                .execute()
                .value
            let nextOrder = (existing.map { $0.rotationOrder }.max() ?? 0) + 1

            let user: User = try await supabase
                .from("users")
                .insert(NewUser(household_id: householdId, name: name, rotation_order: nextOrder))
                .select()
                .single()
                .execute()
                .value

            // Load the household the user just joined.
            let household: Household = try await supabase
                .from("households")
                .select()
                .eq("id", value: householdId)
                .single()
                .execute()
                .value

            // Single-use code: delete it.
            try await supabase.from("join_codes").delete().eq("code", value: code).execute()

            currentUser = user
            currentHousehold = household
            await fetchHouseholdData()
            isLoading = false
            return true
        } catch {
            errorMessage = "Failed to join household: \(error.localizedDescription)"
            isLoading = false
            return false
        }
    }

    /// Load all users and items for the current household.
    func fetchHouseholdData() async {
        guard let householdId = currentHousehold?.id else { return }

        do {
            let users: [User] = try await supabase
                .from("users")
                .select()
                .eq("household_id", value: householdId)
                .order("rotation_order")
                .execute()
                .value

            let items: [Item] = try await supabase
                .from("items")
                .select()
                .eq("household_id", value: householdId)
                .order("name")
                .execute()
                .value

            householdUsers = users
            householdItems = items

            // Keep currentUser in sync with the source of truth (pause state, etc.).
            if let myId = currentUser?.id, let me = users.first(where: { $0.id == myId }) {
                currentUser = me
            }
        } catch {
            errorMessage = "Failed to fetch household data: \(error.localizedDescription)"
        }
    }

    // MARK: - Rotation

    /// Mark an item fulfilled, rotate to the next user, and refresh.
    func markItemFulfilled(_ item: Item) async {
        guard let user = currentUser else { return }

        let rotationService = RotationService(supabase: supabase)
        let updated = await rotationService.markItemFulfilled(
            item: item,
            fulfilledByUser: user,
            users: householdUsers
        )

        if updated == nil {
            errorMessage = "Couldn't update \(item.name). Check your connection and try again."
        }

        await fetchHouseholdData()
    }

    // MARK: - Pause / Resume

    /// Pause the current user's turns until a given date (skipped in rotation).
    func pauseMyTurn(until: Date) async {
        guard let userId = currentUser?.id else { return }

        do {
            try await supabase
                .from("users")
                .update(PauseUpdate(paused_until: SupabaseDate.string(from: until)))
                .eq("id", value: userId)
                .execute()
        } catch {
            errorMessage = "Failed to pause turn: \(error.localizedDescription)"
        }

        await fetchHouseholdData()
    }

    /// Resume rotation (clear pause) — "I'm back".
    func resumeMyTurns() async {
        guard let userId = currentUser?.id else { return }

        do {
            try await supabase
                .from("users")
                .update(PauseUpdate(paused_until: nil))
                .eq("id", value: userId)
                .execute()
        } catch {
            errorMessage = "Failed to resume turns: \(error.localizedDescription)"
        }

        await fetchHouseholdData()
    }

    var isCurrentUserPaused: Bool {
        currentUser?.isPaused ?? false
    }

    // MARK: - Leave

    func leaveHousehold() async {
        guard let userId = currentUser?.id else { return }

        do {
            try await supabase.from("users").delete().eq("id", value: userId).execute()
            currentUser = nil
            currentHousehold = nil
            householdUsers = []
            householdItems = []
        } catch {
            errorMessage = "Failed to leave household: \(error.localizedDescription)"
        }
    }
}
