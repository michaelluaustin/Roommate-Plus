import SwiftUI

struct JoinHouseholdView: View {
    @StateObject private var authService = AuthService.shared
    @Environment(\.dismiss) var dismiss
    @State private var userName = ""
    @State private var joinCode = ""

    var body: some View {
        VStack(spacing: 20) {
            Text("Join Household")
                .font(.title2)
                .fontWeight(.bold)

            VStack(alignment: .leading, spacing: 12) {
                Text("Your Name")
                    .font(.caption)
                    .foregroundColor(.gray)
                TextField("Enter your name", text: $userName)
                    .textFieldStyle(.roundedBorder)

                Text("Join Code (6 digits)")
                    .font(.caption)
                    .foregroundColor(.gray)
                TextField("000000", text: $joinCode)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)
            }

            Button(action: joinHousehold) {
                if authService.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Join")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(userName.isEmpty || joinCode.isEmpty || authService.isLoading)

            if let error = authService.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            Spacer()

            Button("Back", action: { dismiss() })
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
    JoinHouseholdView()
}
