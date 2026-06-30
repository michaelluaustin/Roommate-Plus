import Foundation

struct History: Identifiable, Codable {
    let id: String
    let householdId: String
    let itemId: String
    let fulfilledByUserId: String
    let fulfilledAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case householdId = "household_id"
        case itemId = "item_id"
        case fulfilledByUserId = "fulfilled_by_user_id"
        case fulfilledAt = "fulfilled_at"
    }
}
