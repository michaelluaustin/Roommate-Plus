import Foundation
import UserNotifications

class NotificationService {
    static let shared = NotificationService()

    // Trash talk variations (sent when assigned). {name}/{item} substituted.
    private let trashTalkCopy = [
        "{name}, you're up for {item}! 🚨",
        "Your turn, {name} — time to grab {item} 🥛",
        "{item} run! You're up, {name} ⏱️",
        "Tag, you're it. Go get {item}, {name} 🏃",
        "{name}, the {item} isn't gonna buy itself ☕",
        "It's showtime! {name}, you're on {item} 🎬",
        "Rotation landed on you, {name}. {item} duty. (you're welcome) 😏",
    ]

    // Celebration variations (sent when fulfilled).
    private let celebrationCopy = [
        "{name} came through with the {item}! 🎉",
        "{name} delivered the {item}. Legend status. 👑",
        "Respect. {name} brought the {item}. 🙌",
        "{name} scored the {item}. +10 roommate points. ⭐",
        "The {item} fairy strikes again! Thanks {name}! 🧚",
    ]

    private func render(_ template: String, name: String, item: String) -> String {
        template
            .replacingOccurrences(of: "{name}", with: name)
            .replacingOccurrences(of: "{item}", with: item)
    }

    // MARK: - Permissions

    func requestAPNsPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    // MARK: - Send Notifications

    /// Trash talk notification when a user is newly assigned an item.
    func sendAssignmentNotification(to user: User, item: Item) async {
        let body = render(trashTalkCopy.randomElement() ?? "{name}, you're up for {item}!",
                          name: user.name, item: item.name)
        await post(title: "Grocery Rotation", body: body)
    }

    /// Celebration notification when an item is fulfilled.
    func sendCelebrationNotification(for item: Item, fulfilledBy user: User, householdUsers: [User]) async {
        let body = render(celebrationCopy.randomElement() ?? "{name} came through with the {item}! 🎉",
                          name: user.name, item: item.name)
        await post(title: "Grocery Delivered!", body: body)
    }

    private func post(title: String, body: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            print("Failed to schedule notification: \(error)")
        }
    }

    // MARK: - Badge (fallback when APNs denied)

    /// Set the app icon badge. Uses the iOS 16+ API which is thread-safe,
    /// avoiding the deprecated main-thread-only UIApplication accessor.
    func setBadgeCount(_ count: Int) async {
        try? await UNUserNotificationCenter.current().setBadgeCount(count)
    }
}
