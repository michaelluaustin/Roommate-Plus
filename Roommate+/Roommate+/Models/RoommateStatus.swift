import SwiftUI

/// A roommate's current presence/mood, shown on the Status tab.
/// Raw values are stored in the `users.status` column.
enum RoommateStatus: String, CaseIterable, Identifiable {
    case available
    case doNotEnter
    case studying
    case lit
    case sleeping
    case away

    var id: String { rawValue }

    /// Fallback for nil / unknown stored values.
    static func from(_ raw: String?) -> RoommateStatus {
        guard let raw, let status = RoommateStatus(rawValue: raw) else { return .available }
        return status
    }

    var label: String {
        switch self {
        case .available: "Available"
        case .doNotEnter: "Don't Come In"
        case .studying: "Out Studying"
        case .lit: "Getting Lit"
        case .sleeping: "Sleeping"
        case .away: "Out"
        }
    }

    var emoji: String {
        switch self {
        case .available: "✅"
        case .doNotEnter: "🚫"
        case .studying: "📚"
        case .lit: "🎉"
        case .sleeping: "😴"
        case .away: "🚶"
        }
    }

    var icon: String {
        switch self {
        case .available: "checkmark.circle.fill"
        case .doNotEnter: "hand.raised.fill"
        case .studying: "book.fill"
        case .lit: "party.popper.fill"
        case .sleeping: "moon.zzz.fill"
        case .away: "figure.walk"
        }
    }

    var color: Color {
        switch self {
        case .available: .mndGreen
        case .doNotEnter: .mndRed
        case .studying: .mndBrightBlue
        case .lit: .mndPink
        case .sleeping: .mndPurple
        case .away: .mndNavy
        }
    }
}
