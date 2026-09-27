import Foundation

struct User: Identifiable, Codable, Equatable {
    let id: String
    let householdId: String
    let name: String
    let email: String?
    let rotationOrder: Int
    let pausedUntilRaw: String?
    let statusRaw: String?
    let statusUpdatedAtRaw: String?
    let avatarUrl: String?
    let avatarUpdatedAtRaw: String?
    let venmoUsername: String?
    let zellePhone: String?
    let createdAtRaw: String?

    var pausedUntil: Date? { SupabaseDate.parse(pausedUntilRaw) }
    var createdAt: Date? { SupabaseDate.parse(createdAtRaw) }
    var statusUpdatedAt: Date? { SupabaseDate.parse(statusUpdatedAtRaw) }
    var avatarUpdatedAt: Date? { SupabaseDate.parse(avatarUpdatedAtRaw) }

    var avatarPublicURL: URL? {
        SupabaseConfig.publicStorageURL(bucket: "avatars", path: avatarUrl, version: avatarUpdatedAtRaw)
    }

    var venmoHandle: String? { PaymentLinks.normalizedVenmoUsername(venmoUsername) }
    var zelleNumber: String? { PaymentLinks.normalizedZellePhone(zellePhone) }

    var status: RoommateStatus { RoommateStatus.from(statusRaw) }

    var isPaused: Bool {
        guard let until = pausedUntil else { return false }
        return until > Date()
    }

    enum CodingKeys: String, CodingKey {
        case id, name, email
        case householdId = "household_id"
        case rotationOrder = "rotation_order"
        case pausedUntilRaw = "paused_until"
        case statusRaw = "status"
        case statusUpdatedAtRaw = "status_updated_at"
        case avatarUrl = "avatar_url"
        case avatarUpdatedAtRaw = "avatar_updated_at"
        case venmoUsername = "venmo_username"
        case zellePhone = "zelle_phone"
        case createdAtRaw = "created_at"
    }
}
