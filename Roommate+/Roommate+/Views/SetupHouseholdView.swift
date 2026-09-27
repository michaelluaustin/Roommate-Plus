import SwiftUI

struct SetupHouseholdView: View {
    @StateObject private var authService = AuthService.shared
    @State private var userName = ""
    @State private var householdName = ""

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    header

                    VStack(alignment: .leading, spacing: 18) {
                        MNDTextField(
                            label: "Your Name",
                            placeholder: "Enter your name",
                            text: $userName
                        )
                        MNDTextField(
                            label: "Household Name",
                            placeholder: "e.g., Apartment 3B",
                            text: $householdName
                        )
                    }
                    .padding(20)
                    .background(scheme == .dark ? Color.mndNightSurface1 : Color.mndSurfaceGray)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    VStack(spacing: 12) {
                        MNDPrimaryButton(
                            title: "Create Household",
                            isLoading: authService.isLoading,
                            disabled: userName.isEmpty || householdName.isEmpty
                        ) {
                            createHousehold()
                        }

                        if let error = authService.errorMessage {
                            MNDErrorBanner(message: error)
                        }
                    }

                    NavigationLink(destination: JoinHouseholdView()) {
                        HStack {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Join Existing Household")
                                .font(.mndTextAction)
                        }
                        .foregroundStyle(Color.mndBlue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 24)
                .padding(.bottom, 40)
            }
            .mondayTheme()
            .mndAppearanceToolbar()
            .navigationDestination(isPresented: Binding(
                get: { authService.currentHousehold != nil },
                set: { _ in }
            )) {
                MainTabView()
                    .navigationBarBackButtonHidden()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Circle().fill(Color.mndRed).frame(width: 10, height: 10)
                Circle().fill(Color.mndOrange).frame(width: 10, height: 10)
                Circle().fill(Color.mndGreen).frame(width: 10, height: 10)
            }

            Text("Roommate+")
                .font(.mndScreenTitle)
                .foregroundStyle(scheme == .dark ? Color.mndDarkTextPrimary : Color.mndTextPrimary)

            Text("Set up your household grocery rotation")
                .font(.mndMeta)
                .foregroundStyle(scheme == .dark ? Color.mndDarkTextSecondary : Color.mndTextSecondary)
        }
    }

    private func createHousehold() {
        Task {
            await authService.createHouseholdAsFirstUser(name: userName, householdName: householdName)
        }
    }
}

#Preview {
    SetupHouseholdView()
}
