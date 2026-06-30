import Foundation

struct History: Identifiable, Codable, Equatable {
    let id: String
    let householdId: String
    let itemId: String
    let fulfilledByUserId: String
    let fulfilledAtRaw: String?

    var fulfilledAt: Date? { SupabaseDate.parse(fulfilledAtRaw) }

    enum CodingKeys: String, CodingKey {
        case id
        case householdId = "household_id"
        case itemId = "item_id"
        case fulfilledByUserId = "fulfilled_by_user_id"
        case fulfilledAtRaw = "fulfilled_at"
    }
}
