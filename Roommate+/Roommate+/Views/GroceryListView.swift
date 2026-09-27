import SwiftUI

struct GroceryListView: View {
    @StateObject private var authService = AuthService.shared
    @State private var showingAddItem = false

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                boardHeader

                if let error = authService.errorMessage {
                    MNDErrorBanner(message: error) {
                        authService.errorMessage = nil
                    }
                }

                if let success = authService.successMessage {
                    MNDSuccessBanner(message: success) {
                        authService.successMessage = nil
                    }
                }

                List {
                    Section {
                        ForEach(Array(authService.householdItems.enumerated()), id: \.element.id) { index, item in
                            GroceryItemRow(
                                item: item,
                                authService: authService,
                                groupColor: MondayDesign.groupColor(for: index)
                            )
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    Task { await authService.deleteItem(item) }
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                            }
                        }
                    } header: {
                        listSectionHeader
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(scheme == .dark ? Color.mndNightCanvas : Color.mndCanvas)
                .contentMargins(.bottom, 72, for: .scrollContent)
                .refreshable {
                    await authService.fetchHouseholdData()
                }
            }
            .overlay(alignment: .bottomTrailing) {
                addItemFAB
            }
            .mondayTheme()
            .mndAppearanceToolbar()
            .navigationTitle("Grocery")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingAddItem) {
                AddItemSheet(authService: authService)
                    .presentationDetents([.medium])
            }
        }
    }

    private var listSectionHeader: some View {
        VStack(alignment: .leading, spacing: 0) {
            MNDGroupHeader(
                name: "Grocery List",
                groupColor: .mndBrightBlue,
                count: authService.householdItems.count
            )

            if !authService.householdItems.isEmpty {
                batteryRollup
                    .padding(.horizontal, 18)
                    .padding(.bottom, 12)
            }
        }
        .textCase(nil)
        .listRowInsets(EdgeInsets())
    }

    private var addItemFAB: some View {
        Button {
            showingAddItem = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Circle().fill(Color.mndBlue))
                .shadow(color: .black.opacity(scheme == .dark ? 0.35 : 0.18), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .padding(.trailing, 20)
        .padding(.bottom, 24)
    }

    private var boardHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let household = authService.currentHousehold {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.mndBrightBlue)
                        .frame(width: 12, height: 12)
                    Text(household.name)
                        .font(.mndBoardTitle)
                        .foregroundStyle(scheme == .dark ? Color.mndDarkTextPrimary : Color.mndTextPrimary)
                }
            }

            if let user = authService.currentUser {
                HStack(spacing: 8) {
                    MNDUserAvatar(user: user)
                    Text("You: \(user.name)")
                        .font(.mndMeta)
                        .foregroundStyle(scheme == .dark ? Color.mndDarkTextSecondary : Color.mndTextSecondary)

                    if authService.isCurrentUserPaused {
                        MNDStatusCell(label: "Paused", color: .mndWarning)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(scheme == .dark ? Color.mndNightSurface1 : Color.mndSurfaceGray)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(scheme == .dark ? Color.mndNightDivider : Color.mndDivider)
                .frame(height: 1)
        }
    }

    private var batteryRollup: some View {
        let segments = rotationSegments
        return MNDBatteryRollup(segments: segments)
            .animation(.easeOut(duration: 0.25), value: segments.map(\.fraction))
    }

    private var rotationSegments: [(color: Color, fraction: CGFloat)] {
        let items = authService.householdItems
        guard !items.isEmpty else { return [] }

        let myId = authService.currentUser?.id
        var myTurn = 0
        var waiting = 0
        var paused = 0

        for item in items {
            guard let assigneeId = item.currentAssigneeId,
                  let assignee = authService.householdUsers.first(where: { $0.id == assigneeId }) else {
                waiting += 1
                continue
            }
            if assignee.isPaused {
                paused += 1
            } else if assigneeId == myId {
                myTurn += 1
            } else {
                waiting += 1
            }
        }

        let total = CGFloat(items.count)
        return [
            (Color.mndOrange, CGFloat(myTurn) / total),
            (Color.mndNavy, CGFloat(waiting) / total),
            (Color.mndWarning, CGFloat(paused) / total)
        ]
    }
}

struct GroceryItemRow: View {
    let item: Item
    let authService: AuthService
    let groupColor: Color

    @State private var isMarkingDone = false

    @Environment(\.colorScheme) private var scheme

    var assignedUser: User? {
        guard let assignedId = item.currentAssigneeId else { return nil }
        return authService.householdUsers.first(where: { $0.id == assignedId })
    }

    var isMyTurn: Bool {
        guard let currentUserId = authService.currentUser?.id else { return false }
        return item.currentAssigneeId == currentUserId
    }

    private var status: (label: String, color: Color) {
        if isMyTurn { return ("Your Turn", Color.mndOrange) }
        if assignedUser?.isPaused == true { return ("Paused", Color.mndWarning) }
        return ("Waiting", Color.mndNavy)
    }

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(groupColor)
                .frame(width: 6)

            HStack(spacing: 10) {
                Text(item.name)
                    .font(.mndItemName)
                    .foregroundStyle(scheme == .dark ? Color.mndDarkTextPrimary : Color.mndTextPrimary)
                    .lineLimit(1)

                Spacer(minLength: 8)

                MNDUserAvatar(
                    user: assignedUser,
                    fallbackName: assignedUser?.name ?? "?",
                    fallbackSeed: assignedUser?.id ?? item.id
                )

                if isMyTurn {
                    Button(action: markFulfilled) {
                        Group {
                            if isMarkingDone {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 12, weight: .semibold))
                                    Text("Mark Done")
                                        .font(.mndStatusLabel)
                                }
                            }
                        }
                        .foregroundStyle(.white)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(RoundedRectangle(cornerRadius: 4).fill(Color.mndGreen))
                    }
                    .buttonStyle(.borderless)
                    .disabled(isMarkingDone)
                } else {
                    MNDStatusCell(label: status.label, color: status.color)
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

    private func markFulfilled() {
        guard !isMarkingDone else { return }
        isMarkingDone = true
        Task {
            await authService.markItemFulfilled(item)
            isMarkingDone = false
        }
    }
}

struct AddItemSheet: View {
    @ObservedObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    @State private var itemName = ""
    @State private var isSaving = false

    var body: some View {
        VStack(spacing: 24) {
            Text("Add Item")
                .font(.mndSection)

            MNDTextField(
                label: "Item name",
                placeholder: "e.g., Paper towels",
                text: $itemName
            )

            MNDPrimaryButton(
                title: "Add to List",
                isLoading: isSaving,
                disabled: itemName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ) {
                saveItem()
            }

            MNDSecondaryButton(title: "Cancel") {
                dismiss()
            }

            Spacer()
        }
        .padding(24)
        .mondayTheme()
    }

    private func saveItem() {
        isSaving = true
        Task {
            let success = await authService.addItem(name: itemName)
            isSaving = false
            if success {
                dismiss()
            }
        }
    }
}

struct JoinCodeSheet: View {
    @Binding var joinCode: String
    let authService: AuthService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: 24) {
            Text("Share This Code")
                .font(.mndSection)
                .foregroundStyle(scheme == .dark ? Color.mndDarkTextPrimary : Color.mndTextPrimary)

            if joinCode.isEmpty {
                MNDPrimaryButton(title: "Generate Join Code") {
                    generateCode()
                }
            } else {
                VStack(spacing: 16) {
                    Text(joinCode)
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.mndBlue)
                        .padding(.vertical, 20)
                        .frame(maxWidth: .infinity)
                        .background(scheme == .dark ? Color.mndNightSurface2 : Color.mndSurfaceGray)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    MNDSecondaryButton(title: "Copy Code", icon: "doc.on.doc") {
                        UIPasteboard.general.string = joinCode
                    }

                    Text("Code expires in 7 days")
                        .font(.mndMeta)
                        .foregroundStyle(scheme == .dark ? Color.mndDarkTextTertiary : Color.mndTextTertiary)
                }
            }

            Spacer()

            MNDPrimaryButton(title: "Done") {
                dismiss()
            }
        }
        .padding(24)
        .mondayTheme()
    }

    private func generateCode() {
        Task {
            if let code = await authService.generateJoinCode() {
                joinCode = code
            }
        }
    }
}

#Preview {
    GroceryListView()
}
