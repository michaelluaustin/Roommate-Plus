import SwiftUI

/// Formats a status change time as relative text, e.g. "just now", "5m ago".
enum StatusTime {
    static func asOf(_ date: Date?) -> String? {
        guard let date else { return nil }

        let seconds = Date().timeIntervalSince(date)
        if seconds < 0 { return "just now" }

        switch seconds {
        case ..<60:
            return "just now"
        case ..<3600:
            return "\(Int(seconds / 60))m ago"
        case ..<86_400:
            return "\(Int(seconds / 3600))h ago"
        case ..<604_800:
            return "\(Int(seconds / 86_400))d ago"
        default:
            return "\(Int(seconds / 604_800))w ago"
        }
    }
}

struct StatusView: View {
    @StateObject private var authService = AuthService.shared
    @State private var showingPicker = false

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if let error = authService.errorMessage {
                        MNDErrorBanner(message: error) {
                            authService.errorMessage = nil
                        }
                    }

                    myStatusCard
                    roommatesSection
                }
                .padding(.horizontal, 18)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            .refreshable {
                await authService.fetchHouseholdData()
            }
            .mondayTheme()
            .mndAppearanceToolbar()
            .navigationTitle("Status")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingPicker) {
                StatusPickerSheet(authService: authService)
                    .presentationDetents([.medium, .large])
            }
        }
    }

    private var myStatusCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Your Status")
                .font(.mndColumnHead)
                .foregroundStyle(scheme == .dark ? Color.mndDarkTextSecondary : Color.mndTextSecondary)

            let status = authService.currentUser?.status ?? .available

            Button {
                showingPicker = true
            } label: {
                HStack(spacing: 12) {
                    Text(status.emoji)
                        .font(.system(size: 28))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(status.label)
                            .font(.mndSection)
                            .foregroundStyle(scheme == .dark ? Color.mndDarkTextPrimary : Color.mndTextPrimary)
                        if let asOf = StatusTime.asOf(authService.currentUser?.statusUpdatedAt) {
                            Text(asOf)
                                .font(.mndMeta)
                                .foregroundStyle(scheme == .dark ? Color.mndDarkTextSecondary : Color.mndTextSecondary)
                        } else {
                            Text("Tap to change")
                                .font(.mndMeta)
                                .foregroundStyle(scheme == .dark ? Color.mndDarkTextSecondary : Color.mndTextSecondary)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.mndTextTertiary)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(status.color.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(status.color, lineWidth: 2)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(MNDPressButtonStyle())
        }
    }

    private var roommatesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Roommates")
                .font(.mndColumnHead)
                .foregroundStyle(scheme == .dark ? Color.mndDarkTextSecondary : Color.mndTextSecondary)

            let others = authService.householdUsers.filter { $0.id != authService.currentUser?.id }

            if others.isEmpty {
                Text("No other roommates yet. Share your join code from the Info tab.")
                    .font(.mndMeta)
                    .foregroundStyle(scheme == .dark ? Color.mndDarkTextTertiary : Color.mndTextTertiary)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(others) { user in
                        RoommateStatusRow(user: user)

                        if user.id != others.last?.id {
                            Rectangle()
                                .fill(scheme == .dark ? Color.mndNightDivider : Color.mndDivider)
                                .frame(height: 1)
                                .padding(.leading, 52)
                        }
                    }
                }
                .background(scheme == .dark ? Color.mndNightSurface1 : Color.mndSurfaceGray)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}

private struct RoommateStatusRow: View {
    let user: User

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: 12) {
            MNDUserAvatar(user: user, size: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(user.name)
                    .font(.mndItemName)
                    .foregroundStyle(scheme == .dark ? Color.mndDarkTextPrimary : Color.mndTextPrimary)
                HStack(spacing: 6) {
                    Text(user.status.emoji)
                        .font(.system(size: 14))
                    Text(user.status.label)
                        .font(.mndMeta)
                        .foregroundStyle(user.status.color)
                }
                if let asOf = StatusTime.asOf(user.statusUpdatedAt) {
                    Text(asOf)
                        .font(.mndMeta)
                        .foregroundStyle(scheme == .dark ? Color.mndDarkTextTertiary : Color.mndTextTertiary)
                }
            }

            Spacer()

            Circle()
                .fill(user.status.color)
                .frame(width: 10, height: 10)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
    }
}

struct StatusPickerSheet: View {
    @ObservedObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        VStack(spacing: 20) {
            Text("Set Your Status")
                .font(.mndSection)
                .foregroundStyle(scheme == .dark ? Color.mndDarkTextPrimary : Color.mndTextPrimary)

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(RoommateStatus.allCases) { status in
                    Button {
                        Task {
                            await authService.setStatus(status)
                            dismiss()
                        }
                    } label: {
                        VStack(spacing: 8) {
                            Text(status.emoji)
                                .font(.system(size: 32))
                            Text(status.label)
                                .font(.mndStatusLabel)
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(RoundedRectangle(cornerRadius: 10).fill(status.color))
                    }
                    .buttonStyle(MNDPressButtonStyle())
                }
            }

            Spacer()

            MNDSecondaryButton(title: "Cancel") {
                dismiss()
            }
        }
        .padding(24)
        .mondayTheme()
    }
}

#Preview {
    StatusView()
}
