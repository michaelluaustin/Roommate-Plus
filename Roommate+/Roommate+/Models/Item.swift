import Foundation

struct Item: Identifiable, Codable {
    let id: String
    let householdId: String
    let name: String
    let currentAssigneeId: String?
    let lastFulfilledByUserId: String?
    let lastFulfilledAt: Date?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case householdId = "household_id"
        case name
        case currentAssigneeId = "current_assignee_id"
        case lastFulfilledByUserId = "last_fulfilled_by_user_id"
        case lastFulfilledAt = "last_fulfilled_at"
        case createdAt = "created_at"
    }
}
