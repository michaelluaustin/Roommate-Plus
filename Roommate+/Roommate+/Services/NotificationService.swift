import Foundation
import UserNotifications

class NotificationService {
    static let shared = NotificationService()

    // Trash talk variations (sent when assigned)
    private let trashTalkCopy = [
        "Sarah, you're up for eggs! 🚨",
        "Your turn! Time to grab some milk 🥛",
        "Bread run! You're up ⏱️",
        "Butter me up — it's your turn! 🧈",
        "Coffee emergency — you're on duty! ☕",
        "It's showtime! Go get those eggs 🎬",
        "Your rotation just came around (you're welcome) 😏",
    ]

    // Celebration variations (sent when fulfilled)
    private let celebrationCopy = [
        "{name} came through with the {item}! 🎉",
        "{name} delivered! {item} is here. Legend status. 👑",
        "Respect. {name} brought the {item}. 🙌",
        "{name} scored the {item}. +10 roommate points. ⭐",
        "The {item} fairy strikes again! Thanks {name}! 🧚",
    ]

    // MARK: - Request Permissions

    func requestAPNsPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    // MARK: - Send Notifications

    /// Send trash talk notification when user is assigned
    func sendAssignmentNotification(to user: User, item: Item) async {
        let message = trashTalkCopy.randomElement() ?? "Your turn is here!"

        let content = UNMutableNotificationContent()
        content.title = "Grocery Rotation"
        content.body = message
        content.badge = NSNumber(value: UIApplication.shared.applicationIconBadgeNumber + 1)
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false))

        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            print("Failed to send assignment notification: \(error)")
        }
    }

    /// Send celebration notification when item is fulfilled
    func sendCelebrationNotification(for item: Item, fulfilledBy user: User, householdUsers: [User]) async {
        var message = celebrationCopy.randomElement() ?? "{name} came through with the {item}! 🎉"
        message = message.replacingOccurrences(of: "{name}", with: user.name)
        message = message.replacingOccurrences(of: "{item}", with: item.name)

        let content = UNMutableNotificationContent()
        content.title = "Grocery Delivered!"
        content.body = message
        content.badge = NSNumber(value: max(0, UIApplication.shared.applicationIconBadgeNumber - 1))
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false))

        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            print("Failed to send celebration notification: \(error)")
        }
    }

    // MARK: - Badge Management

    /// Update app badge (used as fallback when APNs denied)
    func updateBadgeCount(_ count: Int) {
        DispatchQueue.main.async {
            UIApplication.shared.applicationIconBadgeNumber = count
        }
    }
}
