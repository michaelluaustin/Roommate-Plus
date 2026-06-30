import Foundation

struct User: Identifiable, Codable {
    let id: String
    let householdId: String
    let name: String
    let email: String?
    let rotationOrder: Int
    let pausedUntil: Date?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case householdId = "household_id"
        case name
        case email
        case rotationOrder = "rotation_order"
        case pausedUntil = "paused_until"
        case createdAt = "created_at"
    }
}
