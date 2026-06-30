import Foundation

struct Household: Identifiable, Codable {
    let id: String
    let name: String
    let createdByUserId: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case createdByUserId = "created_by_user_id"
        case createdAt = "created_at"
    }
}
