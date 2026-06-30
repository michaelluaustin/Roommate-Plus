import Foundation

struct Household: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let createdByUserId: String?
    let createdAtRaw: String?

    var createdAt: Date? { SupabaseDate.parse(createdAtRaw) }

    enum CodingKeys: String, CodingKey {
        case id, name
        case createdByUserId = "created_by_user_id"
        case createdAtRaw = "created_at"
    }
}
