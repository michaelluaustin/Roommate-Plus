import SwiftUI

struct JoinHouseholdView: View {
    @StateObject private var authService = AuthService.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @State private var userName = ""
    @State private var joinCode = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Join Household")
                        .font(.mndBoardTitle)
                        .foregroundStyle(scheme == .dark ? Color.mndDarkTextPrimary : Color.mndTextPrimary)

                    Text("Enter the 6-digit code from your roommate")
                        .font(.mndMeta)
                        .foregroundStyle(scheme == .dark ? Color.mndDarkTextSecondary : Color.mndTextSecondary)
                }

                VStack(alignment: .leading, spacing: 18) {
                    MNDTextField(
                        label: "Your Name",
                        placeholder: "Enter your name",
                        text: $userName
                    )
                    MNDTextField(
                        label: "Join Code",
                        placeholder: "000000",
                        text: $joinCode,
                        keyboardType: .numberPad
                    )
                }
                .padding(20)
                .background(scheme == .dark ? Color.mndNightSurface1 : Color.mndSurfaceGray)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(spacing: 12) {
                    MNDPrimaryButton(
                        title: "Join",
                        isLoading: authService.isLoading,
                        disabled: userName.isEmpty || joinCode.isEmpty
                    ) {
                        joinHousehold()
                    }

                    if let error = authService.errorMessage {
                        MNDErrorBanner(message: error)
                    }

                    MNDSecondaryButton(title: "Back", icon: "chevron.left") {
                        dismiss()
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .mondayTheme()
        .mndAppearanceToolbar()
        .navigationBarBackButtonHidden()
        .navigationDestination(isPresented: Binding(
            get: { authService.currentHousehold != nil },
            set: { _ in }
        )) {
            MainTabView()
                .navigationBarBackButtonHidden()
        }
    }

    private func joinHousehold() {
        Task {
            let success = await authService.joinHouseholdWithCode(name: userName, code: joinCode)
            if success {
                await authService.fetchHouseholdData()
            }
        }
    }
}

#Preview {
    NavigationStack {
        JoinHouseholdView()
    }
}
