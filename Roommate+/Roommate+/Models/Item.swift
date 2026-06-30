import Foundation

struct Item: Identifiable, Codable, Equatable {
    let id: String
    let householdId: String
    let name: String
    let currentAssigneeId: String?
    let lastFulfilledByUserId: String?
    let lastFulfilledAtRaw: String?
    let createdAtRaw: String?

    var lastFulfilledAt: Date? { SupabaseDate.parse(lastFulfilledAtRaw) }
    var createdAt: Date? { SupabaseDate.parse(createdAtRaw) }

    enum CodingKeys: String, CodingKey {
        case id, name
        case householdId = "household_id"
        case currentAssigneeId = "current_assignee_id"
        case lastFulfilledByUserId = "last_fulfilled_by_user_id"
        case lastFulfilledAtRaw = "last_fulfilled_at"
        case createdAtRaw = "created_at"
    }
}
