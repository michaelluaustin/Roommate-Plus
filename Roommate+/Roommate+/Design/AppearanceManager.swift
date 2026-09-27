import Combine
import SwiftUI

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    var label: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var icon: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max.fill"
        case .dark: "moon.fill"
        }
    }
}

@MainActor
final class AppearanceManager: ObservableObject {
    static let shared = AppearanceManager()

    private static let storageKey = "appearance_mode"

    @Published var mode: AppearanceMode {
        didSet {
            UserDefaults.standard.set(mode.rawValue, forKey: Self.storageKey)
        }
    }

    private init() {
        if
            let raw = UserDefaults.standard.string(forKey: Self.storageKey),
            let saved = AppearanceMode(rawValue: raw)
        {
            mode = saved
        } else {
            mode = .system
        }
    }
}

struct MNDAppearanceMenu: View {
    @ObservedObject private var appearance = AppearanceManager.shared

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Menu {
            ForEach(AppearanceMode.allCases) { option in
                Button {
                    appearance.mode = option
                } label: {
                    Label {
                        Text(option.label)
                    } icon: {
                        Image(systemName: option.icon)
                    }
                    if appearance.mode == option {
                        Image(systemName: "checkmark")
                    }
                }
            }
        } label: {
            Image(systemName: menuIcon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(scheme == .dark ? Color.mndDarkTextPrimary : Color.mndTextPrimary)
                .frame(width: 44, height: 44)
        }
        .accessibilityLabel("Appearance")
        .accessibilityHint("Choose light, dark, or system appearance")
    }

    private var menuIcon: String {
        switch appearance.mode {
        case .system: scheme == .dark ? "moon.fill" : "sun.max.fill"
        case .light: "sun.max.fill"
        case .dark: "moon.fill"
        }
    }
}

extension View {
    func mndAppearanceToolbar() -> some View {
        toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                MNDAppearanceMenu()
            }
        }
    }
}
