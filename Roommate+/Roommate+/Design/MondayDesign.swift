import SwiftUI

// MARK: - Colors

extension Color {
    static let mndCanvas = Color.white
    static let mndSurfaceGray = Color(red: 0.965, green: 0.969, blue: 0.984)
    static let mndSurfacePressed = Color(red: 0.929, green: 0.937, blue: 0.961)
    static let mndDivider = Color(red: 0.902, green: 0.914, blue: 0.941)
    static let mndCellBorder = Color(red: 0.816, green: 0.831, blue: 0.894)

    static let mndNightCanvas = Color(red: 0.094, green: 0.106, blue: 0.204)
    static let mndNightSurface1 = Color(red: 0.125, green: 0.141, blue: 0.247)
    static let mndNightSurface2 = Color(red: 0.161, green: 0.184, blue: 0.298)
    static let mndNightDivider = Color(red: 0.208, green: 0.231, blue: 0.361)
    static let mndNightCellBorder = Color(red: 0.239, green: 0.263, blue: 0.416)

    static let mndTextPrimary = Color(red: 0.196, green: 0.200, blue: 0.220)
    static let mndTextSecondary = Color(red: 0.404, green: 0.408, blue: 0.475)
    static let mndTextTertiary = Color(red: 0.588, green: 0.600, blue: 0.651)
    static let mndDarkTextPrimary = Color(red: 0.961, green: 0.965, blue: 0.973)
    static let mndDarkTextSecondary = Color(red: 0.655, green: 0.686, blue: 0.776)
    static let mndDarkTextTertiary = Color(red: 0.420, green: 0.451, blue: 0.580)

    static let mndBlue = Color(red: 0.000, green: 0.451, blue: 0.918)
    static let mndBluePressed = Color(red: 0.000, green: 0.376, blue: 0.761)

    static let mndRed = Color(red: 0.886, green: 0.267, blue: 0.361)
    static let mndOrange = Color(red: 0.992, green: 0.671, blue: 0.239)
    static let mndGreen = Color(red: 0.000, green: 0.784, blue: 0.459)
    static let mndBrightBlue = Color(red: 0.341, green: 0.608, blue: 0.988)
    static let mndPurple = Color(red: 0.635, green: 0.365, blue: 0.863)
    static let mndIndigo = Color(red: 0.333, green: 0.349, blue: 0.875)
    static let mndYellow = Color(red: 1.000, green: 0.796, blue: 0.000)
    static let mndTeal = Color(red: 0.000, green: 0.824, blue: 0.824)
    static let mndPink = Color(red: 1.000, green: 0.082, blue: 0.541)
    static let mndBrightGreen = Color(red: 0.612, green: 0.827, blue: 0.149)
    static let mndNavy = Color(red: 0.200, green: 0.239, blue: 0.431)

    static let mndSuccess = Color(red: 0.000, green: 0.784, blue: 0.459)
    static let mndError = Color(red: 0.886, green: 0.267, blue: 0.361)
    static let mndWarning = Color(red: 0.992, green: 0.671, blue: 0.239)

    static let mndGroupPalette: [Color] = [
        .mndBrightBlue, .mndPurple, .mndTeal, .mndPink, .mndIndigo, .mndBrightGreen, .mndOrange
    ]
}

func mndOnColor(_ bg: Color) -> Color {
    [Color.mndYellow, .mndTeal, .mndBrightGreen].contains(bg) ? .mndTextPrimary : .white
}

// MARK: - Typography (SF Pro fallback; bundle Figtree for brand match)

extension Font {
    static func mnd(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    static let mndScreenTitle = Font.system(size: 32, weight: .heavy)
    static let mndBoardTitle = Font.system(size: 26, weight: .bold)
    static let mndGroupHeader = Font.system(size: 22, weight: .heavy)
    static let mndSection = Font.system(size: 18, weight: .bold)
    static let mndBody = Font.system(size: 16, weight: .regular)
    static let mndItemName = Font.system(size: 14, weight: .medium)
    static let mndColumnHead = Font.system(size: 13, weight: .semibold)
    static let mndMeta = Font.system(size: 14, weight: .regular)
    static let mndStatusLabel = Font.system(size: 11, weight: .bold)
    static let mndButton = Font.system(size: 15, weight: .semibold)
    static let mndTextAction = Font.system(size: 14, weight: .semibold)
    static let mndPersonInit = Font.system(size: 9, weight: .bold)
}

// MARK: - Theme

struct MondayTheme: ViewModifier {
    @Environment(\.colorScheme) private var scheme

    var canvas: Color { scheme == .dark ? .mndNightCanvas : .mndCanvas }
    var surface: Color { scheme == .dark ? .mndNightSurface1 : .mndSurfaceGray }
    var textPrimary: Color { scheme == .dark ? .mndDarkTextPrimary : .mndTextPrimary }
    var textSecondary: Color { scheme == .dark ? .mndDarkTextSecondary : .mndTextSecondary }
    var divider: Color { scheme == .dark ? .mndNightDivider : .mndDivider }

    func body(content: Content) -> some View {
        content
            .background(canvas)
            .foregroundStyle(textPrimary)
    }
}

extension View {
    func mondayTheme() -> some View { modifier(MondayTheme()) }
}

// MARK: - Helpers

enum MondayDesign {
    static func initials(for name: String) -> String {
        let parts = name.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first.map(String.init) }
        return letters.joined().uppercased()
    }

    static func personColor(for seed: String) -> Color {
        let hash = abs(seed.hashValue)
        return Color.mndGroupPalette[hash % Color.mndGroupPalette.count]
    }

    static func groupColor(for index: Int) -> Color {
        Color.mndGroupPalette[index % Color.mndGroupPalette.count]
    }
}

// MARK: - Components

struct MNDPrimaryButton: View {
    let title: String
    var isLoading = false
    var disabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(title)
                        .font(.mndButton)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .foregroundStyle(.white)
            .background(disabled ? Color.mndBlue.opacity(0.4) : Color.mndBlue)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(MNDPressButtonStyle())
        .disabled(disabled || isLoading)
    }
}

struct MNDSecondaryButton: View {
    let title: String
    var icon: String? = nil
    var tint: Color? = nil
    let action: () -> Void

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                }
                Text(title)
                    .font(.mndTextAction)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .foregroundStyle(tint ?? (scheme == .dark ? .mndDarkTextPrimary : .mndTextPrimary))
            .background(scheme == .dark ? Color.mndNightSurface2 : Color.mndCanvas)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(scheme == .dark ? Color.mndNightDivider : Color.mndDivider, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(MNDPressButtonStyle())
    }
}

struct MNDTextField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default

    @Environment(\.colorScheme) private var scheme
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.mndColumnHead)
                .foregroundStyle(scheme == .dark ? Color.mndDarkTextSecondary : Color.mndTextSecondary)

            TextField(placeholder, text: $text)
                .font(.mndBody)
                .keyboardType(keyboardType)
                .focused($focused)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(scheme == .dark ? Color.mndNightSurface2 : Color.mndSurfaceGray)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(
                            focused ? Color.mndBlue : (scheme == .dark ? Color.mndNightDivider : Color.mndDivider),
                            lineWidth: focused ? 1.5 : 1
                        )
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

struct MNDErrorBanner: View {
    let message: String
    var onDismiss: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14, weight: .semibold))
            Text(message)
                .font(.mndMeta)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
            if let onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.mndError)
    }
}

struct MNDSuccessBanner: View {
    let message: String
    var onDismiss: (() -> Void)? = nil
    var autoDismissSeconds: Double = 5

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14, weight: .semibold))
            Text(message)
                .font(.mndMeta)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.mndSuccess)
        .task(id: message) {
            guard let onDismiss else { return }
            try? await Task.sleep(for: .seconds(autoDismissSeconds))
            onDismiss()
        }
    }
}

struct MNDPersonAvatar: View {
    let initials: String
    let color: Color
    var size: CGFloat = 24

    var body: some View {
        Text(initials)
            .font(size > 32 ? .system(size: size * 0.36, weight: .bold) : .mndPersonInit)
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Circle().fill(color))
    }
}

struct MNDUserAvatar: View {
    let user: User?
    var fallbackName: String = "?"
    var fallbackSeed: String = ""
    var size: CGFloat = 24

    private var initials: String {
        MondayDesign.initials(for: user?.name ?? fallbackName)
    }

    private var color: Color {
        MondayDesign.personColor(for: user?.id ?? fallbackSeed)
    }

    var body: some View {
        if let url = user?.avatarPublicURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    MNDPersonAvatar(initials: initials, color: color, size: size)
                default:
                    Circle()
                        .fill(color.opacity(0.35))
                        .overlay {
                            ProgressView()
                                .scaleEffect(size > 32 ? 1 : 0.6)
                        }
                }
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
        } else {
            MNDPersonAvatar(initials: initials, color: color, size: size)
        }
    }
}

struct MNDStatusCell: View {
    let label: String
    let color: Color

    var body: some View {
        Text(label.uppercased())
            .font(.mndStatusLabel)
            .foregroundStyle(mndOnColor(color))
            .frame(minWidth: 72)
            .padding(.vertical, 5)
            .padding(.horizontal, 10)
            .background(RoundedRectangle(cornerRadius: 4).fill(color))
    }
}

struct MNDBoardItemRow: View {
    let groupColor: Color
    let name: String
    let personInitials: String
    let personColor: Color
    let statusLabel: String
    let statusColor: Color
    var onStatusTap: (() -> Void)? = nil

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(groupColor)
                .frame(width: 6)

            HStack(spacing: 10) {
                Text(name)
                    .font(.mndItemName)
                    .foregroundStyle(scheme == .dark ? Color.mndDarkTextPrimary : Color.mndTextPrimary)
                    .lineLimit(1)

                Spacer(minLength: 8)

                MNDPersonAvatar(initials: personInitials, color: personColor)

                if let onStatusTap {
                    Button(action: onStatusTap) {
                        MNDStatusCell(label: statusLabel, color: statusColor)
                    }
                    .buttonStyle(.plain)
                } else {
                    MNDStatusCell(label: statusLabel, color: statusColor)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(scheme == .dark ? Color.mndNightDivider : Color.mndDivider)
                .frame(height: 1)
        }
    }
}

struct MNDGroupHeader: View {
    let name: String
    let groupColor: Color
    let count: Int

    var body: some View {
        HStack(spacing: 8) {
            Text(name)
                .font(.mndGroupHeader)
                .foregroundStyle(groupColor)
            Text("\(count) items")
                .font(.mndColumnHead)
                .foregroundStyle(Color.mndTextTertiary)
            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }
}

struct MNDBatteryRollup: View {
    let segments: [(color: Color, fraction: CGFloat)]

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                ForEach(Array(segments.enumerated()), id: \.offset) { _, seg in
                    if seg.fraction > 0 {
                        Rectangle()
                            .fill(seg.color)
                            .frame(width: geo.size.width * seg.fraction)
                    }
                }
            }
        }
        .frame(height: 24)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(scheme == .dark ? Color.mndNightSurface2 : Color.mndSurfaceGray)
        )
    }
}

struct MNDPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
