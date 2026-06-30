import SwiftUI

struct GroceryListView: View {
    @StateObject private var authService = AuthService.shared
    @State private var showingJoinCode = false
    @State private var joinCode = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    if let household = authService.currentHousehold {
                        Text(household.name)
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    if let user = authService.currentUser {
                        Text("You: \(user.name)")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.systemGray6))

                // Error banner
                if let error = authService.errorMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text(error)
                            .font(.caption)
                        Spacer()
                        Button(action: { authService.errorMessage = nil }) {
                            Image(systemName: "xmark.circle.fill")
                        }
                    }
                    .foregroundColor(.white)
                    .padding(10)
                    .background(Color.red)
                }

                // Grocery Items
                List {
                    ForEach(authService.householdItems) { item in
                        GroceryItemRow(item: item, authService: authService)
                    }
                }
                .refreshable {
                    await authService.fetchHouseholdData()
                }

                // Footer Actions
                VStack(spacing: 12) {
                    if authService.isCurrentUserPaused {
                        Button(action: resumeTurns) {
                            Label("I'm Back — Resume My Turns", systemImage: "play.circle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                    } else {
                        Button(action: pauseTurns) {
                            Label("Pause My Turns (away)", systemImage: "pause.circle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }

                    Button(action: { showingJoinCode = true }) {
                        Label("Share Join Code", systemImage: "link")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button(action: leaveHousehold) {
                        Label("Leave Household", systemImage: "door.left.hand.open")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)
                }
                .padding()
            }
            .task {
                await authService.fetchHouseholdData()
            }
            .sheet(isPresented: $showingJoinCode) {
                JoinCodeSheet(joinCode: $joinCode, authService: authService)
            }
        }
    }

    private func leaveHousehold() {
        Task {
            await authService.leaveHousehold()
        }
    }

    private func pauseTurns() {
        Task {
            // Pause for 3 days by default — covers a typical trip.
            let until = Date().addingTimeInterval(3 * 24 * 60 * 60)
            await authService.pauseMyTurn(until: until)
        }
    }

    private func resumeTurns() {
        Task {
            await authService.resumeMyTurns()
        }
    }
}

struct GroceryItemRow: View {
    let item: Item
    let authService: AuthService

    var assignedUser: User? {
        guard let assignedId = item.currentAssigneeId else { return nil }
        return authService.householdUsers.first(where: { $0.id == assignedId })
    }

    var assignedUserName: String {
        assignedUser?.name ?? "Unassigned"
    }

    var assignedUserIsPaused: Bool {
        guard let paused = assignedUser?.pausedUntil else { return false }
        return paused > Date()
    }

    var isMyTurn: Bool {
        guard let currentUserId = authService.currentUser?.id else { return false }
        return item.currentAssigneeId == currentUserId
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.headline)
                HStack(spacing: 4) {
                    Text("Assigned: \(assignedUserName)")
                        .font(.caption)
                        .foregroundColor(.gray)
                    if assignedUserIsPaused {
                        Text("(paused)")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }

            Spacer()

            if isMyTurn {
                Button(action: markFulfilled) {
                    Label("Done", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .tint(.green)
            } else {
                Text(isMyTurn ? "Your Turn!" : "-")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }

    private func markFulfilled() {
        Task {
            await authService.markItemFulfilled(item)
        }
    }
}

struct JoinCodeSheet: View {
    @Binding var joinCode: String
    let authService: AuthService
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text("Share This Code")
                .font(.title2)
                .fontWeight(.bold)

            VStack(spacing: 12) {
                if joinCode.isEmpty {
                    Button(action: generateCode) {
                        Text("Generate Join Code")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    VStack(spacing: 12) {
                        Text(joinCode)
                            .font(.system(size: 28, weight: .bold, design: .monospaced))
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)

                        Button(action: {
                            UIPasteboard.general.string = joinCode
                        }) {
                            Label("Copy Code", systemImage: "doc.on.doc")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)

                        Text("Code expires in 7 days")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }

            Spacer()

            Button("Done", action: { dismiss() })
                .frame(maxWidth: .infinity)
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private func generateCode() {
        Task {
            if let code = await authService.generateJoinCode() {
                DispatchQueue.main.async {
                    self.joinCode = code
                }
            }
        }
    }
}

#Preview {
    GroceryListView()
}
