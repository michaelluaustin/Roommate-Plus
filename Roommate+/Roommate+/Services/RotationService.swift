import Foundation
import Supabase

enum RotationResult {
    case success(Item)
    case failure(String)
}

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
    /// log history, and fire notifications.
    func markItemFulfilled(
        item: Item,
        fulfilledByUser: User,
        users: [User]
    ) async -> RotationResult {
        guard item.currentAssigneeId == fulfilledByUser.id else {
            return .failure("This item is no longer your turn. Pull to refresh.")
        }

        guard !users.isEmpty else {
            return .failure("No roommates loaded. Pull to refresh and try again.")
        }

        guard let nextUser = nextUserInRotation(currentUser: fulfilledByUser, allUsers: users) else {
            return .failure("No one is available in the rotation.")
        }

        let nowISO = SupabaseDate.string(from: Date())

        do {
            try await supabase
                .from("items")
                .update(FulfillUpdate(
                    current_assignee_id: nextUser.id,
                    last_fulfilled_by_user_id: fulfilledByUser.id,
                    last_fulfilled_at: nowISO
                ))
                .eq("id", value: item.id)
                .execute()

            try await supabase
                .from("history")
                .insert(NewHistory(
                    household_id: item.householdId,
                    item_id: item.id,
                    fulfilled_by_user_id: fulfilledByUser.id,
                    fulfilled_at: nowISO
                ))
                .execute()

            let updated = Item(
                id: item.id,
                householdId: item.householdId,
                name: item.name,
                currentAssigneeId: nextUser.id,
                lastFulfilledByUserId: fulfilledByUser.id,
                lastFulfilledAtRaw: nowISO,
                createdAtRaw: item.createdAtRaw
            )

            let notifications = NotificationService.shared
            await notifications.sendCelebrationNotification(
                for: item, fulfilledBy: fulfilledByUser, householdUsers: users
            )
            if nextUser.id != fulfilledByUser.id {
                await notifications.sendAssignmentNotification(to: nextUser, item: updated)
            }

            return .success(updated)
        } catch {
            return .failure("Couldn't update \(item.name): \(error.localizedDescription)")
        }
    }

    /// Next user in strict round-robin order, skipping anyone currently paused.
    func nextUserInRotation(currentUser: User, allUsers: [User]) -> User? {
        let active = allUsers
            .filter { !$0.isPaused || $0.id == currentUser.id }
            .sorted { $0.rotationOrder < $1.rotationOrder }

        guard !active.isEmpty else { return nil }
        guard let idx = active.firstIndex(where: { $0.id == currentUser.id }) else {
            return active.first
        }

        for step in 1...active.count {
            let candidate = active[(idx + step) % active.count]
            if candidate.id == currentUser.id { return candidate }
            if !candidate.isPaused { return candidate }
        }
        return active[(idx + 1) % active.count]
    }
}
