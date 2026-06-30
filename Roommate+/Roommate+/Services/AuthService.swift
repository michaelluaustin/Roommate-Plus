import Foundation
import Supabase

class AuthService: ObservableObject {
    static let shared = AuthService()

    private let supabaseURL = URL(string: "https://YOUR_PROJECT_REF.supabase.co")!
    private let supabaseKey = "REDACTED_SUPABASE_ANON_KEY"

    lazy var supabase = SupabaseClient(supabaseURL: supabaseURL, supabaseKey: supabaseKey)

    @Published var currentUser: User?
    @Published var currentHousehold: Household?
    @Published var householdUsers: [User] = []
    @Published var householdItems: [Item] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    // MARK: - Date Parsing

    /// Parse a Postgres/ISO8601 timestamp string from Supabase into a Date.
    /// Supabase returns timestamps with or without fractional seconds, so try both.
    static func parseDate(_ value: Any?) -> Date? {
        guard let str = value as? String else { return nil }

        let withFractional = ISO8601DateFormatter()
        withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFractional.date(from: str) { return date }

        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        if let date = plain.date(from: str) { return date }

        // Postgres default "2026-06-30 11:32:00" (space, no TZ)
        let postgres = DateFormatter()
        postgres.dateFormat = "yyyy-MM-dd HH:mm:ss"
        postgres.timeZone = TimeZone(identifier: "UTC")
        return postgres.date(from: str)
    }

    // MARK: - Auth Methods

    /// First user creates household and becomes admin
    func createHouseholdAsFirstUser(name: String, householdName: String) async {
        DispatchQueue.main.async {
            self.isLoading = true
            self.errorMessage = nil
        }

        do {
            // Create household
            let household = try await supabase.database
                .from("households")
                .insert([
                    "name": householdName,
                    "created_by_user_id": UUID().uuidString
                ])
                .select()
                .single()
                .execute()
                .value as! [String: Any]

            let householdId = household["id"] as! String

            // Create user as admin (rotation_order = 1)
            let user = try await supabase.database
                .from("users")
                .insert([
                    "household_id": householdId,
                    "name": name,
                    "rotation_order": 1
                ])
                .select()
                .single()
                .execute()
                .value as! [String: Any]

            // Create default items and assign to this user
            let items = ["Milk", "Eggs", "Bread", "Butter", "Coffee"]
            for item in items {
                _ = try await supabase.database
                    .from("items")
                    .insert([
                        "household_id": householdId,
                        "name": item,
                        "current_assignee_id": user["id"] as! String
                    ])
                    .execute()
            }

            DispatchQueue.main.async {
                self.currentHousehold = Household(
                    id: householdId,
                    name: householdName,
                    createdByUserId: user["id"] as! String,
                    createdAt: Date()
                )
                self.currentUser = User(
                    id: user["id"] as! String,
                    householdId: householdId,
                    name: name,
                    email: nil,
                    rotationOrder: 1,
                    pausedUntil: nil,
                    createdAt: Date()
                )
                self.isLoading = false
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Failed to create household: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }

    /// Admin generates join code for roommates (6-digit, expires in 7 days)
    func generateJoinCode() async -> String? {
        do {
            let code = String(format: "%06d", Int.random(in: 0..<1000000))
            let expiresAt = Date().addingTimeInterval(7 * 24 * 60 * 60) // 7 days

            guard let householdId = currentHousehold?.id else { return nil }

            let joinCode = try await supabase.database
                .from("join_codes")
                .insert([
                    "household_id": householdId,
                    "code": code,
                    "expires_at": expiresAt.ISO8601Format()
                ])
                .select()
                .single()
                .execute()
                .value as! [String: Any]

            return joinCode["code"] as? String
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Failed to generate join code: \(error.localizedDescription)"
            }
            return nil
        }
    }

    /// Roommate joins household with code
    func joinHouseholdWithCode(name: String, code: String) async -> Bool {
        DispatchQueue.main.async {
            self.isLoading = true
            self.errorMessage = nil
        }

        do {
            // Validate code and get household
            let codeRecord = try await supabase.database
                .from("join_codes")
                .select()
                .eq("code", value: code)
                .single()
                .execute()
                .value as! [String: Any]

            guard let householdId = codeRecord["household_id"] as? String else {
                throw NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid join code"])
            }

            // Get current max rotation order in household
            let users = try await supabase.database
                .from("users")
                .select()
                .eq("household_id", value: householdId)
                .execute()
                .value as! [[String: Any]]

            let maxRotationOrder = (users.map { $0["rotation_order"] as? Int ?? 0 }.max() ?? 0) + 1

            // Add user to household
            let newUser = try await supabase.database
                .from("users")
                .insert([
                    "household_id": householdId,
                    "name": name,
                    "rotation_order": maxRotationOrder
                ])
                .select()
                .single()
                .execute()
                .value as! [String: Any]

            // Mark code as used (delete it)
            try await supabase.database
                .from("join_codes")
                .delete()
                .eq("code", value: code)
                .execute()

            DispatchQueue.main.async {
                self.currentUser = User(
                    id: newUser["id"] as! String,
                    householdId: householdId,
                    name: name,
                    email: nil,
                    rotationOrder: maxRotationOrder,
                    pausedUntil: nil,
                    createdAt: Date()
                )
                self.isLoading = false
            }

            return true
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Failed to join household: \(error.localizedDescription)"
                self.isLoading = false
            }
            return false
        }
    }

    /// Fetch household data and items
    func fetchHouseholdData() async {
        guard let householdId = currentHousehold?.id else { return }

        do {
            let users = try await supabase.database
                .from("users")
                .select()
                .eq("household_id", value: householdId)
                .execute()
                .value as! [[String: Any]]

            let items = try await supabase.database
                .from("items")
                .select()
                .eq("household_id", value: householdId)
                .execute()
                .value as! [[String: Any]]

            DispatchQueue.main.async {
                self.householdUsers = users.map { u in
                    User(
                        id: u["id"] as! String,
                        householdId: u["household_id"] as! String,
                        name: u["name"] as! String,
                        email: u["email"] as? String,
                        rotationOrder: u["rotation_order"] as! Int,
                        pausedUntil: Self.parseDate(u["paused_until"]),
                        createdAt: Self.parseDate(u["created_at"]) ?? Date()
                    )
                }
                self.householdItems = items.map { i in
                    Item(
                        id: i["id"] as! String,
                        householdId: i["household_id"] as! String,
                        name: i["name"] as! String,
                        currentAssigneeId: i["current_assignee_id"] as? String,
                        lastFulfilledByUserId: i["last_fulfilled_by_user_id"] as? String,
                        lastFulfilledAt: Self.parseDate(i["last_fulfilled_at"]),
                        createdAt: Self.parseDate(i["created_at"]) ?? Date()
                    )
                }

                // Keep currentUser's pause state in sync with the source of truth.
                if let myId = self.currentUser?.id,
                   let me = self.householdUsers.first(where: { $0.id == myId }) {
                    self.currentUser = me
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Failed to fetch household data: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Rotation

    /// Mark an item fulfilled by the current user, rotate to next, and refresh UI.
    /// Wraps RotationService so the View talks to a single ObservableObject.
    func markItemFulfilled(_ item: Item) async {
        guard let user = currentUser else { return }

        let rotationService = RotationService(supabase: supabase)
        let updated = await rotationService.markItemFulfilled(
            item: item,
            fulfilledByUser: user,
            users: householdUsers
        )

        if updated == nil {
            DispatchQueue.main.async {
                self.errorMessage = "Couldn't update \(item.name). Check your connection and try again."
            }
        }

        // Refresh from source of truth so every row reflects the new assignment.
        await fetchHouseholdData()
    }

    // MARK: - User Management

    /// Pause user's turn (defer by N rotations)
    func pauseMyTurn(until: Date) async {
        guard let userId = currentUser?.id else { return }

        do {
            _ = try await supabase.database
                .from("users")
                .update(["paused_until": until.ISO8601Format()])
                .eq("id", value: userId)
                .execute()

            DispatchQueue.main.async {
                var updated = self.currentUser
                updated?.pausedUntil = until
                self.currentUser = updated
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Failed to pause turn: \(error.localizedDescription)"
            }
        }

        await fetchHouseholdData()
    }

    /// Resume rotation (clear pause) — "I'm back"
    func resumeMyTurns() async {
        guard let userId = currentUser?.id else { return }

        do {
            _ = try await supabase.database
                .from("users")
                .update(["paused_until": NSNull()])
                .eq("id", value: userId)
                .execute()
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Failed to resume turns: \(error.localizedDescription)"
            }
        }

        await fetchHouseholdData()
    }

    /// Convenience: is the current user currently paused?
    var isCurrentUserPaused: Bool {
        guard let paused = currentUser?.pausedUntil else { return false }
        return paused > Date()
    }

    /// Leave household
    func leaveHousehold() async {
        guard let userId = currentUser?.id else { return }

        do {
            _ = try await supabase.database
                .from("users")
                .delete()
                .eq("id", value: userId)
                .execute()

            DispatchQueue.main.async {
                self.currentUser = nil
                self.currentHousehold = nil
                self.householdUsers = []
                self.householdItems = []
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Failed to leave household: \(error.localizedDescription)"
            }
        }
    }
}
