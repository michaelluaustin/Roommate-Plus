import Foundation
import Supabase

class RotationService {
    let supabase: SupabaseClient

    init(supabase: SupabaseClient) {
        self.supabase = supabase
    }

    private struct FulfillUpdate: Encodable {
        let current_assignee_id: String
        let last_fulfilled_by_user_id: String
        let last_fulfilled_at: String
    }
    private struct NewHistory: Encodable {
        let household_id: String
        let item_id: String
        let fulfilled_by_user_id: String
        let fulfilled_at: String
    }

    /// Mark item fulfilled, rotate to the next active user (skipping paused),
    /// log history, and fire notifications. Last-write-wins on conflicts.
    func markItemFulfilled(
        item: Item,
        fulfilledByUser: User,
        users: [User]
    ) async -> Item? {
        guard let nextUser = nextUserInRotation(currentUser: fulfilledByUser, allUsers: users) else {
            return nil
        }

        let nowISO = SupabaseDate.string(from: Date())

        do {
            let updated: Item = try await supabase
                .from("items")
                .update(FulfillUpdate(
                    current_assignee_id: nextUser.id,
                    last_fulfilled_by_user_id: fulfilledByUser.id,
                    last_fulfilled_at: nowISO
                ))
                .eq("id", value: item.id)
                .select()
                .single()
                .execute()
                .value

            try await supabase
                .from("history")
                .insert(NewHistory(
                    household_id: item.householdId,
                    item_id: item.id,
                    fulfilled_by_user_id: fulfilledByUser.id,
                    fulfilled_at: nowISO
                ))
                .execute()

            let notifications = NotificationService.shared
            await notifications.sendCelebrationNotification(
                for: item, fulfilledBy: fulfilledByUser, householdUsers: users
            )
            await notifications.sendAssignmentNotification(to: nextUser, item: updated)

            return updated
        } catch {
            print("Failed to mark item fulfilled: \(error)")
            return nil
        }
    }

    /// Next user in strict round-robin order, skipping anyone currently paused.
    /// Ordering is by rotationOrder so it's stable regardless of array order.
    func nextUserInRotation(currentUser: User, allUsers: [User]) -> User? {
        let active = allUsers
            .filter { !$0.isPaused || $0.id == currentUser.id }
            .sorted { $0.rotationOrder < $1.rotationOrder }

        guard !active.isEmpty else { return nil }
        guard let idx = active.firstIndex(where: { $0.id == currentUser.id }) else {
            return active.first
        }

        // Walk forward to the next non-paused user (excludes self unless solo).
        for step in 1...active.count {
            let candidate = active[(idx + step) % active.count]
            if candidate.id == currentUser.id { return candidate } // solo household
            if !candidate.isPaused { return candidate }
        }
        return active[(idx + 1) % active.count]
    }
}
