import Foundation
import Supabase

class RotationService {
    let supabase: SupabaseClient

    init(supabase: SupabaseClient) {
        self.supabase = supabase
    }

    /// Mark item as fulfilled and rotate to next user
    /// Uses last-write-wins policy for offline conflicts
    func markItemFulfilled(
        item: Item,
        fulfilledByUser: User,
        users: [User]
    ) async -> Item? {
        // Find the next user in rotation order (respecting pause)
        let activeUsers = users.filter { $0.pausedUntil == nil || $0.pausedUntil! < Date() }
        guard let currentIndex = activeUsers.firstIndex(where: { $0.rotationOrder == fulfilledByUser.rotationOrder }) else {
            return nil
        }

        let nextIndex = (currentIndex + 1) % activeUsers.count
        let nextUser = activeUsers[nextIndex]

        do {
            // Update item assignment (last-write-wins)
            let updated = try await supabase.database
                .from("items")
                .update([
                    "current_assignee_id": nextUser.id,
                    "last_fulfilled_by_user_id": fulfilledByUser.id,
                    "last_fulfilled_at": Date().ISO8601Format()
                ])
                .eq("id", value: item.id)
                .select()
                .single()
                .execute()
                .value as! [String: Any]

            // Log to history
            _ = try await supabase.database
                .from("history")
                .insert([
                    "household_id": item.householdId,
                    "item_id": item.id,
                    "fulfilled_by_user_id": fulfilledByUser.id,
                    "fulfilled_at": Date().ISO8601Format()
                ])
                .execute()

            // Send notifications
            let notificationService = NotificationService.shared
            await notificationService.sendCelebrationNotification(
                for: item,
                fulfilledBy: fulfilledByUser,
                householdUsers: users
            )
            await notificationService.sendAssignmentNotification(to: nextUser, item: item)

            return Item(
                id: updated["id"] as! String,
                householdId: updated["household_id"] as! String,
                name: updated["name"] as! String,
                currentAssigneeId: updated["current_assignee_id"] as? String,
                lastFulfilledByUserId: updated["last_fulfilled_by_user_id"] as? String,
                lastFulfilledAt: Date(),
                createdAt: Date()
            )
        } catch {
            print("Failed to mark item fulfilled: \(error)")
            return nil
        }
    }

    /// Calculate next rotation user (strict round-robin)
    /// Skips users whose paused_until > now
    func nextUserInRotation(
        currentUser: User,
        allUsers: [User]
    ) -> User? {
        let activeUsers = allUsers.filter { $0.pausedUntil == nil || $0.pausedUntil! < Date() }

        guard let currentIndex = activeUsers.firstIndex(where: { $0.id == currentUser.id }) else {
            return nil
        }

        let nextIndex = (currentIndex + 1) % activeUsers.count
        return activeUsers[nextIndex]
    }
}
