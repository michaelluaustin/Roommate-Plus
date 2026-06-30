import SwiftUI

struct SetupHouseholdView: View {
    @StateObject private var authService = AuthService.shared
    @State private var userName = ""
    @State private var householdName = ""
    @State private var showingJoinCode = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Set Up Your Household")
                    .font(.title2)
                    .fontWeight(.bold)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Your Name")
                        .font(.caption)
                        .foregroundColor(.gray)
                    TextField("Enter your name", text: $userName)
                        .textFieldStyle(.roundedBorder)

                    Text("Household Name")
                        .font(.caption)
                        .foregroundColor(.gray)
                    TextField("e.g., Apartment 3B", text: $householdName)
                        .textFieldStyle(.roundedBorder)
                }

                Button(action: createHousehold) {
                    if authService.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Create Household")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(userName.isEmpty || householdName.isEmpty || authService.isLoading)

                if let error = authService.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }

                Spacer()

                Divider()

                NavigationLink("Join Existing Household", destination: JoinHouseholdView())
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            .padding()
            .navigationDestination(isPresented: Binding(
                get: { authService.currentHousehold != nil },
                set: { _ in }
            )) {
                GroceryListView()
                    .navigationBarBackButtonHidden()
            }
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
