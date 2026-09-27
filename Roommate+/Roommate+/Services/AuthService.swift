import Combine
import Foundation
import Supabase

@MainActor
class AuthService: ObservableObject {
    static let shared = AuthService()

    private let supabaseURL = SupabaseConfig.supabaseURL
    private let supabaseKey = SupabaseConfig.supabaseKey

    let supabase: SupabaseClient

    init() {
        supabase = SupabaseClient(supabaseURL: supabaseURL, supabaseKey: supabaseKey)
    }

    @Published var currentUser: User?
    @Published var currentHousehold: Household?
    @Published var householdUsers: [User] = []
    @Published var householdItems: [Item] = []
    @Published var householdExpenses: [SplitExpense] = []
    @Published var expenseParticipants: [ExpenseParticipant] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    /// True while we attempt to restore a saved session on launch. The root view
    /// shows a loading state instead of flashing the setup screen.
    @Published var isRestoring = true

    private enum SessionKeys {
        static let userId = "session_user_id"
        static let householdId = "session_household_id"
    }

    private func persistSession() {
        let defaults = UserDefaults.standard
        defaults.set(currentUser?.id, forKey: SessionKeys.userId)
        defaults.set(currentHousehold?.id, forKey: SessionKeys.householdId)
    }

    private func clearSession() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: SessionKeys.userId)
        defaults.removeObject(forKey: SessionKeys.householdId)
    }

    /// Restore a previously saved household session on app launch, if any.
    func restoreSession() async {
        let defaults = UserDefaults.standard
        guard
            let userId = defaults.string(forKey: SessionKeys.userId),
            let householdId = defaults.string(forKey: SessionKeys.householdId)
        else {
            isRestoring = false
            return
        }

        do {
            let household: Household = try await supabase
                .from("households")
                .select()
                .eq("id", value: householdId)
                .single()
                .execute()
                .value

            let user: User = try await supabase
                .from("users")
                .select()
                .eq("id", value: userId)
                .single()
                .execute()
                .value

            currentHousehold = household
            currentUser = user
            await fetchHouseholdData()
        } catch {
            // A real failure (not a cancellation) means the saved household or
            // user no longer exists — drop the stale session.
            if shouldReport(error) {
                clearSession()
                currentUser = nil
                currentHousehold = nil
            }
        }

        isRestoring = false
    }

    /// SwiftUI cancels in-flight tasks on refresh, navigation, and theme changes.
    /// Those are not user-visible failures.
    private func shouldReport(_ error: Error) -> Bool {
        if error is CancellationError { return false }
        if Task.isCancelled { return false }
        if let urlError = error as? URLError, urlError.code == .cancelled { return false }
        return true
    }

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
    private struct StatusUpdate: Encodable {
        let status: String
        let status_updated_at: String
    }
    private struct NewExpense: Encodable {
        let household_id: String
        let created_by_user_id: String
        let title: String
        let note: String?
        let amount_cents: Int
    }
    private struct NewExpenseParticipant: Encodable {
        let expense_id: String
        let user_id: String
        let share_cents: Int
    }
    private struct SettleUpdate: Encodable {
        let settled_at: String
        let settled_by_user_id: String
    }
    private struct AvatarUpdate: Encodable {
        let avatar_url: String?
        let avatar_updated_at: String?
    }
    private struct PaymentInfoUpdate: Encodable {
        let venmo_username: String?
        let zelle_phone: String?
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
            persistSession()
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
            persistSession()
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

            let expenses: [SplitExpense] = try await supabase
                .from("expenses")
                .select()
                .eq("household_id", value: householdId)
                .order("created_at", ascending: false)
                .execute()
                .value

            let expenseIds = expenses.map(\.id)
            let participants: [ExpenseParticipant]
            if expenseIds.isEmpty {
                participants = []
            } else {
                participants = try await supabase
                    .from("expense_participants")
                    .select()
                    .in("expense_id", values: expenseIds)
                    .execute()
                    .value
            }

            householdUsers = users
            householdItems = items
            householdExpenses = expenses
            expenseParticipants = participants

            // Keep currentUser in sync with the source of truth (pause state, etc.).
            if let myId = currentUser?.id, let me = users.first(where: { $0.id == myId }) {
                currentUser = me
            }
        } catch {
            guard shouldReport(error) else { return }
            errorMessage = "Failed to fetch household data: \(error.localizedDescription)"
        }
    }

    // MARK: - Items

    /// Add a grocery item, assigned to the first active roommate in rotation order.
    func addItem(name: String) async -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let householdId = currentHousehold?.id else { return false }

        let assignee = householdUsers
            .filter { !$0.isPaused }
            .sorted { $0.rotationOrder < $1.rotationOrder }
            .first
            ?? householdUsers.sorted { $0.rotationOrder < $1.rotationOrder }.first

        guard let assignee else {
            errorMessage = "No household members found."
            return false
        }

        do {
            try await supabase
                .from("items")
                .insert(NewItem(
                    household_id: householdId,
                    name: trimmed,
                    current_assignee_id: assignee.id
                ))
                .execute()

            await fetchHouseholdData()
            return true
        } catch {
            guard shouldReport(error) else { return false }
            errorMessage = "Failed to add item: \(error.localizedDescription)"
            return false
        }
    }

    /// Remove a grocery item from the household list.
    func deleteItem(_ item: Item) async {
        do {
            // History rows block item delete unless the FK cascades.
            try await supabase
                .from("history")
                .delete()
                .eq("item_id", value: item.id)
                .execute()

            try await supabase
                .from("items")
                .delete()
                .eq("id", value: item.id)
                .execute()

            await fetchHouseholdData()
        } catch {
            guard shouldReport(error) else { return }
            errorMessage = "Failed to remove item: \(error.localizedDescription)"
        }
    }

    // MARK: - Rotation

    /// Mark an item fulfilled, rotate to the next user, and refresh.
    func markItemFulfilled(_ item: Item) async {
        guard let user = currentUser else { return }

        errorMessage = nil
        successMessage = nil

        let rotationService = RotationService(supabase: supabase)
        let result = await rotationService.markItemFulfilled(
            item: item,
            fulfilledByUser: user,
            users: householdUsers
        )

        switch result {
        case .success(let updated):
            if let nextId = updated.currentAssigneeId,
               nextId != user.id,
               let nextUser = householdUsers.first(where: { $0.id == nextId }) {
                successMessage = "\(item.name) done — \(nextUser.name) is up next."
            } else {
                successMessage = "\(item.name) marked done!"
            }
            await fetchHouseholdData()
        case .failure(let message):
            errorMessage = message
        }
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

    var splitBundles: [SplitExpenseBundle] {
        householdExpenses
            .map { expense in
                SplitExpenseBundle(
                    expense: expense,
                    participants: expenseParticipants.filter { $0.expenseId == expense.id }
                )
            }
            .sorted {
                ($0.expense.createdAt ?? .distantPast) > ($1.expense.createdAt ?? .distantPast)
            }
    }

    // MARK: - Status

    /// Update the current user's presence/mood status.
    func setStatus(_ status: RoommateStatus) async {
        guard let userId = currentUser?.id else { return }

        do {
            try await supabase
                .from("users")
                .update(StatusUpdate(
                    status: status.rawValue,
                    status_updated_at: SupabaseDate.string(from: Date())
                ))
                .eq("id", value: userId)
                .execute()
        } catch {
            guard shouldReport(error) else { return }
            errorMessage = "Failed to update status: \(error.localizedDescription)"
        }

        await fetchHouseholdData()
    }

    // MARK: - Split

    /// Create an expense split equally among the selected roommates.
    func addSplitExpense(
        title: String,
        note: String,
        amountCents: Int,
        participantUserIds: [String]
    ) async -> Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            let householdId = currentHousehold?.id,
            let payerId = currentUser?.id,
            !trimmedTitle.isEmpty,
            amountCents > 0,
            participantUserIds.count >= 2
        else {
            errorMessage = "Enter a title, amount, and select at least 2 people."
            return false
        }

        let shares = SplitMoney.equalShares(amountCents: amountCents, count: participantUserIds.count)
        let orderedIds = householdUsers
            .filter { participantUserIds.contains($0.id) }
            .map(\.id)

        do {
            let expense: SplitExpense = try await supabase
                .from("expenses")
                .insert(NewExpense(
                    household_id: householdId,
                    created_by_user_id: payerId,
                    title: trimmedTitle,
                    note: trimmedNote.isEmpty ? nil : trimmedNote,
                    amount_cents: amountCents
                ))
                .select()
                .single()
                .execute()
                .value

            let participantRows = orderedIds.enumerated().map { index, userId in
                NewExpenseParticipant(
                    expense_id: expense.id,
                    user_id: userId,
                    share_cents: shares[index]
                )
            }
            try await supabase.from("expense_participants").insert(participantRows).execute()

            successMessage = "Split added."
            await fetchHouseholdData()
            return true
        } catch {
            guard shouldReport(error) else { return false }
            errorMessage = "Failed to add split: \(error.localizedDescription)"
            return false
        }
    }

    /// Mark a debtor's share as settled. Either the debtor or payer can do this.
    func settleShare(expenseId: String, debtorUserId: String) async {
        guard let currentUserId = currentUser?.id else { return }

        guard let bundle = splitBundles.first(where: { $0.id == expenseId }),
              let debtor = bundle.debtors.first(where: { $0.userId == debtorUserId }),
              !debtor.isSettled else { return }

        let isDebtor = currentUserId == debtorUserId
        let isPayer = currentUserId == bundle.payerId
        guard isDebtor || isPayer else { return }

        do {
            try await supabase
                .from("expense_participants")
                .update(SettleUpdate(
                    settled_at: SupabaseDate.string(from: Date()),
                    settled_by_user_id: currentUserId
                ))
                .eq("expense_id", value: expenseId)
                .eq("user_id", value: debtorUserId)
                .execute()

            if let name = householdUsers.first(where: { $0.id == debtorUserId })?.name {
                successMessage = "\(name)'s share settled."
            }
            await fetchHouseholdData()
        } catch {
            guard shouldReport(error) else { return }
            errorMessage = "Failed to settle share: \(error.localizedDescription)"
        }
    }

    /// Remove a split expense. Only the creator should call this from the UI.
    func deleteSplitExpense(_ expense: SplitExpense) async {
        do {
            try await supabase
                .from("expenses")
                .delete()
                .eq("id", value: expense.id)
                .execute()

            successMessage = "Split deleted."
            await fetchHouseholdData()
        } catch {
            guard shouldReport(error) else { return }
            errorMessage = "Failed to delete split: \(error.localizedDescription)"
        }
    }

    // MARK: - Profile Photo

    private static let avatarBucket = "avatars"

    /// Upload a profile photo for the current user.
    func uploadProfilePhoto(_ imageData: Data) async -> Bool {
        guard let userId = currentUser?.id else { return false }
        guard let jpeg = AvatarImageProcessor.jpegData(from: imageData) else {
            errorMessage = "Could not process that image."
            return false
        }

        let path = "\(userId)/avatar.jpg"
        let updatedAt = SupabaseDate.string(from: Date())

        do {
            try await supabase.storage
                .from(Self.avatarBucket)
                .upload(
                    path,
                    data: jpeg,
                    options: FileOptions(contentType: "image/jpeg", upsert: true)
                )

            try await supabase
                .from("users")
                .update(AvatarUpdate(avatar_url: path, avatar_updated_at: updatedAt))
                .eq("id", value: userId)
                .execute()

            successMessage = "Profile photo updated."
            await fetchHouseholdData()
            return true
        } catch {
            guard shouldReport(error) else { return false }
            errorMessage = "Failed to upload photo: \(error.localizedDescription)"
            return false
        }
    }

    /// Remove the current user's profile photo.
    func removeProfilePhoto() async {
        guard let userId = currentUser?.id, let path = currentUser?.avatarUrl else { return }

        do {
            _ = try await supabase.storage
                .from(Self.avatarBucket)
                .remove(paths: [path])

            try await supabase
                .from("users")
                .update(AvatarUpdate(avatar_url: nil, avatar_updated_at: nil))
                .eq("id", value: userId)
                .execute()

            successMessage = "Profile photo removed."
            await fetchHouseholdData()
        } catch {
            guard shouldReport(error) else { return }
            errorMessage = "Failed to remove photo: \(error.localizedDescription)"
        }
    }

    /// Save Venmo username and Zelle phone for the current user.
    func updatePaymentInfo(venmoUsername: String, zellePhone: String) async -> Bool {
        guard let userId = currentUser?.id else { return false }

        let venmo = PaymentLinks.normalizedVenmoUsername(venmoUsername)
        let zelle = PaymentLinks.normalizedZellePhone(zellePhone)

        do {
            try await supabase
                .from("users")
                .update(PaymentInfoUpdate(venmo_username: venmo, zelle_phone: zelle))
                .eq("id", value: userId)
                .execute()

            successMessage = "Payment info saved."
            await fetchHouseholdData()
            return true
        } catch {
            guard shouldReport(error) else { return false }
            errorMessage = "Failed to save payment info: \(error.localizedDescription)"
            return false
        }
    }

    // MARK: - Leave

    func leaveHousehold() async {
        guard let userId = currentUser?.id else { return }

        do {
            try await supabase.from("users").delete().eq("id", value: userId).execute()
            clearSession()
            currentUser = nil
            currentHousehold = nil
            householdUsers = []
            householdItems = []
            householdExpenses = []
            expenseParticipants = []
        } catch {
            errorMessage = "Failed to leave household: \(error.localizedDescription)"
        }
    }
}
