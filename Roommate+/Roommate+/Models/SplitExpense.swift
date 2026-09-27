import Foundation

struct SplitExpense: Identifiable, Codable, Equatable {
    let id: String
    let householdId: String
    let createdByUserId: String
    let title: String
    let note: String?
    let amountCents: Int
    let createdAtRaw: String?

    var createdAt: Date? { SupabaseDate.parse(createdAtRaw) }

    enum CodingKeys: String, CodingKey {
        case id, title, note
        case householdId = "household_id"
        case createdByUserId = "created_by_user_id"
        case amountCents = "amount_cents"
        case createdAtRaw = "created_at"
    }
}

struct ExpenseParticipant: Identifiable, Codable, Equatable {
    let id: String
    let expenseId: String
    let userId: String
    let shareCents: Int
    let settledAtRaw: String?
    let settledByUserId: String?

    var settledAt: Date? { SupabaseDate.parse(settledAtRaw) }
    var isSettled: Bool { settledAt != nil }

    enum CodingKeys: String, CodingKey {
        case id
        case expenseId = "expense_id"
        case userId = "user_id"
        case shareCents = "share_cents"
        case settledAtRaw = "settled_at"
        case settledByUserId = "settled_by_user_id"
    }
}

struct SplitExpenseBundle: Identifiable, Equatable {
    let expense: SplitExpense
    let participants: [ExpenseParticipant]

    var id: String { expense.id }

    var payerId: String { expense.createdByUserId }

    var debtors: [ExpenseParticipant] {
        participants.filter { $0.userId != payerId }
    }

    var unsettledDebtors: [ExpenseParticipant] {
        debtors.filter { !$0.isSettled }
    }

    var isFullySettled: Bool {
        debtors.allSatisfy(\.isSettled)
    }

    /// When the last debtor settled their share.
    var fullySettledAt: Date? {
        let dates = debtors.compactMap(\.settledAt)
        guard dates.count == debtors.count, !dates.isEmpty else { return nil }
        return dates.max()
    }
}

enum SplitMoney {
    static func format(cents: Int) -> String {
        let amount = Double(cents) / 100.0
        return String(format: "$%.2f", amount)
    }

    /// Split `amountCents` equally among `count` people; remainder pennies go to the first slots.
    static func equalShares(amountCents: Int, count: Int) -> [Int] {
        guard count > 0 else { return [] }
        let base = amountCents / count
        let remainder = amountCents % count
        return (0..<count).map { index in
            base + (index < remainder ? 1 : 0)
        }
    }

    /// Net balance with each roommate from active (not fully settled) expenses.
    /// Positive = they owe you; negative = you owe them.
    static func netBalances(
        currentUserId: String,
        bundles: [SplitExpenseBundle]
    ) -> [String: Int] {
        var balances: [String: Int] = [:]

        for bundle in bundles where !bundle.isFullySettled {
            let payerId = bundle.payerId
            for debtor in bundle.unsettledDebtors {
                let amount = debtor.shareCents
                if currentUserId == payerId {
                    balances[debtor.userId, default: 0] += amount
                } else if currentUserId == debtor.userId {
                    balances[payerId, default: 0] -= amount
                }
            }
        }

        return balances.filter { $0.value != 0 }
    }
}
