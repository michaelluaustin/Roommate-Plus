import Foundation

struct User: Identifiable, Codable, Equatable {
    let id: String
    let householdId: String
    let name: String
    let email: String?
    let rotationOrder: Int
    let pausedUntilRaw: String?
    let createdAtRaw: String?

    var pausedUntil: Date? { SupabaseDate.parse(pausedUntilRaw) }
    var createdAt: Date? { SupabaseDate.parse(createdAtRaw) }

    var isPaused: Bool {
        guard let until = pausedUntil else { return false }
        return until > Date()
    }

    enum CodingKeys: String, CodingKey {
        case id, name, email
        case householdId = "household_id"
        case rotationOrder = "rotation_order"
        case pausedUntilRaw = "paused_until"
        case createdAtRaw = "created_at"
    }
}
