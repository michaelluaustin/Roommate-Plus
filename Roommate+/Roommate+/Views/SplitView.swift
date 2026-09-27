import SwiftUI

struct SplitView: View {
    @StateObject private var authService = AuthService.shared
    @State private var showingAddSplit = false
    @State private var showingSettledHistory = false

    @Environment(\.colorScheme) private var scheme

    private var activeBundles: [SplitExpenseBundle] {
        authService.splitBundles.filter { !$0.isFullySettled }
    }

    private var settledBundles: [SplitExpenseBundle] {
        authService.splitBundles
            .filter(\.isFullySettled)
            .sorted { ($0.fullySettledAt ?? .distantPast) > ($1.fullySettledAt ?? .distantPast) }
    }

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

                Group {
                    if activeBundles.isEmpty {
                        GeometryReader { geometry in
                            ScrollView {
                                emptyState
                                    .frame(width: geometry.size.width, height: geometry.size.height)
                            }
                            .refreshable {
                                await authService.fetchHouseholdData()
                            }
                        }
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(Array(activeBundles.enumerated()), id: \.element.id) { index, bundle in
                                    NavigationLink(value: bundle.id) {
                                        SplitExpenseRow(
                                            bundle: bundle,
                                            users: authService.householdUsers,
                                            groupColor: MondayDesign.groupColor(for: index)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.bottom, 88)
                        }
                        .refreshable {
                            await authService.fetchHouseholdData()
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                settledBottomBar
            }
            .overlay(alignment: .bottomTrailing) {
                addSplitFAB
            }
            .mondayTheme()
            .mndAppearanceToolbar()
            .navigationTitle("Split")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingAddSplit) {
                AddSplitSheet(authService: authService)
                    .presentationDetents([.large])
            }
            .sheet(isPresented: $showingSettledHistory) {
                SettledHistoryView(
                    bundles: settledBundles,
                    users: authService.householdUsers
                )
            }
            .navigationDestination(for: String.self) { expenseId in
                if let bundle = authService.splitBundles.first(where: { $0.id == expenseId }) {
                    SplitExpenseDetailView(bundle: bundle, authService: authService)
                }
            }
        }
    }

    private var boardHeader: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let household = authService.currentHousehold {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.mndPurple)
                        .frame(width: 12, height: 12)
                    Text(household.name)
                        .font(.mndBoardTitle)
                        .foregroundStyle(scheme == .dark ? Color.mndDarkTextPrimary : Color.mndTextPrimary)
                }
                .padding(.horizontal, 18)
            }

            balancesCard
                .padding(.horizontal, 18)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 16)
        .background(scheme == .dark ? Color.mndNightSurface1 : Color.mndSurfaceGray)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(scheme == .dark ? Color.mndNightDivider : Color.mndDivider)
                .frame(height: 1)
        }
    }

    private var addSplitFAB: some View {
        Button {
            showingAddSplit = true
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
        .padding(.bottom, 76)
    }

    private var settledBottomBar: some View {
        Button {
            showingSettledHistory = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 14, weight: .semibold))
                Text("Settled")
                    .font(.mndTextAction)
                Spacer()
                Text("\(settledBundles.count)")
                    .font(.mndMeta)
                    .foregroundStyle(scheme == .dark ? Color.mndDarkTextTertiary : Color.mndTextTertiary)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(scheme == .dark ? Color.mndDarkTextTertiary : Color.mndTextTertiary)
            }
            .foregroundStyle(scheme == .dark ? Color.mndDarkTextPrimary : Color.mndTextPrimary)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(scheme == .dark ? Color.mndNightSurface1 : Color.mndSurfaceGray)
        }
        .buttonStyle(.plain)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(scheme == .dark ? Color.mndNightDivider : Color.mndDivider)
                .frame(height: 1)
        }
    }

    private var balancesCard: some View {
        let myId = authService.currentUser?.id ?? ""
        let balances = SplitMoney.netBalances(currentUserId: myId, bundles: activeBundles)

        return VStack(alignment: .leading, spacing: 10) {
            Text("Balances")
                .font(.mndSection)
                .foregroundStyle(scheme == .dark ? Color.mndDarkTextPrimary : Color.mndTextPrimary)

            if balances.isEmpty {
                Text("All settled up")
                    .font(.mndMeta)
                    .foregroundStyle(scheme == .dark ? Color.mndDarkTextSecondary : Color.mndTextSecondary)
            } else {
                ForEach(sortedBalanceEntries(balances), id: \.user.id) { entry in
                    HStack {
                        MNDUserAvatar(user: entry.user)
                        Text(balanceLabel(for: entry))
                            .font(.mndBody)
                            .foregroundStyle(scheme == .dark ? Color.mndDarkTextPrimary : Color.mndTextPrimary)
                        Spacer()
                        Text(SplitMoney.format(cents: abs(entry.cents)))
                            .font(.mndItemName)
                            .foregroundStyle(entry.cents > 0 ? Color.mndGreen : Color.mndRed)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(scheme == .dark ? Color.mndNightSurface2 : Color.mndCanvas)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(scheme == .dark ? Color.mndNightDivider : Color.mndDivider, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func sortedBalanceEntries(_ balances: [String: Int]) -> [(user: User, cents: Int)] {
        balances.compactMap { userId, cents in
            guard let user = authService.householdUsers.first(where: { $0.id == userId }) else { return nil }
            return (user, cents)
        }
        .sorted { abs($0.cents) > abs($1.cents) }
    }

    private func balanceLabel(for entry: (user: User, cents: Int)) -> String {
        if entry.cents > 0 {
            return "\(entry.user.name) owes you"
        }
        return "You owe \(entry.user.name)"
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "dollarsign.circle")
                .font(.system(size: 36))
                .foregroundStyle(Color.mndTextTertiary)
            Text("No active splits")
                .font(.mndSection)
                .foregroundStyle(scheme == .dark ? Color.mndDarkTextSecondary : Color.mndTextSecondary)
            Text("Tap + to share an expense with roommates.")
                .font(.mndMeta)
                .foregroundStyle(scheme == .dark ? Color.mndDarkTextTertiary : Color.mndTextTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(.horizontal, 18)
    }
}

struct SplitExpenseRow: View {
    let bundle: SplitExpenseBundle
    let users: [User]
    let groupColor: Color

    @Environment(\.colorScheme) private var scheme

    private func user(for id: String) -> User? {
        users.first { $0.id == id }
    }

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(groupColor)
                .frame(width: 6)

            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(bundle.expense.title)
                        .font(.mndItemName)
                        .foregroundStyle(scheme == .dark ? Color.mndDarkTextPrimary : Color.mndTextPrimary)
                        .lineLimit(1)

                    Text(SplitMoney.format(cents: bundle.expense.amountCents))
                        .font(.mndMeta)
                        .foregroundStyle(scheme == .dark ? Color.mndDarkTextSecondary : Color.mndTextSecondary)
                }

                Spacer(minLength: 8)

                HStack(spacing: -6) {
                    ForEach(bundle.unsettledDebtors) { debtor in
                        MNDUserAvatar(
                            user: user(for: debtor.userId),
                            fallbackName: user(for: debtor.userId)?.name ?? "?",
                            fallbackSeed: debtor.userId
                        )
                        .overlay(Circle().strokeBorder(scheme == .dark ? Color.mndNightSurface1 : Color.mndCanvas, lineWidth: 2))
                    }
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

struct SplitExpenseDetailView: View {
    let bundle: SplitExpenseBundle
    @ObservedObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @State private var settlingUserId: String?

    /// Prefer the live copy from AuthService so payment info / settle state stay fresh.
    private var liveBundle: SplitExpenseBundle {
        authService.splitBundles.first(where: { $0.id == bundle.id }) ?? bundle
    }

    private var isCreator: Bool {
        authService.currentUser?.id == liveBundle.expense.createdByUserId
    }

    private func user(for id: String) -> User? {
        authService.householdUsers.first { $0.id == id }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(liveBundle.expense.title)
                        .font(.mndSection)
                        .foregroundStyle(scheme == .dark ? Color.mndDarkTextPrimary : Color.mndTextPrimary)

                    Text(SplitMoney.format(cents: liveBundle.expense.amountCents))
                        .font(.mndBoardTitle)
                        .foregroundStyle(Color.mndBlue)

                    if let note = liveBundle.expense.note, !note.isEmpty {
                        Text(note)
                            .font(.mndBody)
                            .foregroundStyle(scheme == .dark ? Color.mndDarkTextSecondary : Color.mndTextSecondary)
                    }

                    if let payer = user(for: liveBundle.payerId) {
                        Text("Paid by \(payer.name)")
                            .font(.mndMeta)
                            .foregroundStyle(scheme == .dark ? Color.mndDarkTextTertiary : Color.mndTextTertiary)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Split between")
                        .font(.mndColumnHead)
                        .foregroundStyle(scheme == .dark ? Color.mndDarkTextSecondary : Color.mndTextSecondary)

                    ForEach(liveBundle.participants.sorted(by: { a, b in
                        let orderA = user(for: a.userId)?.rotationOrder ?? 0
                        let orderB = user(for: b.userId)?.rotationOrder ?? 0
                        return orderA < orderB
                    })) { participant in
                        participantRow(participant)
                    }
                }

                if isCreator {
                    MNDSecondaryButton(title: "Delete Split", tint: .mndRed) {
                        Task {
                            await authService.deleteSplitExpense(liveBundle.expense)
                            dismiss()
                        }
                    }
                }
            }
            .padding(24)
        }
        .mondayTheme()
        .navigationTitle("Split Details")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func participantRow(_ participant: ExpenseParticipant) -> some View {
        let participantUser = user(for: participant.userId)
        let name = participantUser?.name ?? "Unknown"
        let isPayer = participant.userId == liveBundle.payerId
        let isMe = participant.userId == authService.currentUser?.id
        let iAmPayer = authService.currentUser?.id == liveBundle.payerId
        let canSettle = !isPayer && !participant.isSettled && (isMe || iAmPayer)
        let payer = user(for: liveBundle.payerId)
        let paymentNote = liveBundle.expense.title
        // Debtor settling their own share — show Venmo / Zelle / Mark Settled.
        let showDebtorPayActions = isMe && !isPayer && !participant.isSettled

        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                MNDUserAvatar(
                    user: participantUser,
                    fallbackName: name,
                    fallbackSeed: participant.userId
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.mndItemName)
                        .foregroundStyle(scheme == .dark ? Color.mndDarkTextPrimary : Color.mndTextPrimary)
                    Text(SplitMoney.format(cents: participant.shareCents))
                        .font(.mndMeta)
                        .foregroundStyle(scheme == .dark ? Color.mndDarkTextSecondary : Color.mndTextSecondary)
                }

                Spacer()

                if isPayer {
                    MNDStatusCell(label: "Paid", color: .mndGreen)
                } else if participant.isSettled {
                    MNDStatusCell(label: "Settled", color: .mndNavy)
                } else if !canSettle {
                    MNDStatusCell(label: "Owes", color: .mndOrange)
                } else if iAmPayer && !isMe {
                    // Payer marking someone else's share — compact settle only.
                    settleButton(for: participant)
                }
            }

            if showDebtorPayActions {
                debtorPaymentActions(
                    participant: participant,
                    payer: payer,
                    paymentNote: paymentNote
                )
            }
        }
        .padding(12)
        .background(scheme == .dark ? Color.mndNightSurface2 : Color.mndSurfaceGray)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private func debtorPaymentActions(
        participant: ExpenseParticipant,
        payer: User?,
        paymentNote: String
    ) -> some View {
        let hasVenmo = payer?.venmoHandle != nil
        let hasZelle = payer?.zelleNumber != nil

        VStack(alignment: .leading, spacing: 8) {
            Text("Pay \(payer?.name ?? "them")")
                .font(.mndColumnHead)
                .foregroundStyle(scheme == .dark ? Color.mndDarkTextSecondary : Color.mndTextSecondary)

            if hasVenmo, let venmo = payer?.venmoHandle {
                Button {
                    PaymentLinks.openVenmo(
                        username: venmo,
                        amountCents: participant.shareCents,
                        note: paymentNote
                    )
                } label: {
                    paymentActionLabel(title: "Pay with Venmo", icon: "v.circle.fill", tint: .mndBrightBlue)
                }
                .buttonStyle(.plain)
            } else {
                paymentHintRow(
                    title: "Venmo unavailable",
                    detail: "\(payer?.name ?? "Payer") hasn’t added a Venmo username in Info."
                )
            }

            if hasZelle, let zelle = payer?.zelleNumber {
                Button {
                    PaymentLinks.copyZelleInfo(
                        phone: zelle,
                        amountCents: participant.shareCents,
                        note: paymentNote
                    )
                    authService.successMessage = "Zelle info copied."
                } label: {
                    paymentActionLabel(title: "Copy for Zelle", icon: "doc.on.doc", tint: .mndPurple)
                }
                .buttonStyle(.plain)
            } else {
                paymentHintRow(
                    title: "Zelle unavailable",
                    detail: "\(payer?.name ?? "Payer") hasn’t added a Zelle phone in Info."
                )
            }

            settleButton(for: participant, fullWidth: true)
        }
    }

    private func paymentHintRow(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.mndTextAction)
                .foregroundStyle(scheme == .dark ? Color.mndDarkTextSecondary : Color.mndTextSecondary)
            Text(detail)
                .font(.mndMeta)
                .foregroundStyle(scheme == .dark ? Color.mndDarkTextTertiary : Color.mndTextTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(scheme == .dark ? Color.mndNightDivider : Color.mndDivider, lineWidth: 1)
        )
    }

    private func paymentActionLabel(title: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
            Text(title)
                .font(.mndTextAction)
            Spacer()
            Image(systemName: "arrow.up.right")
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(.white)
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 8).fill(tint))
    }

    @ViewBuilder
    private func settleButton(for participant: ExpenseParticipant, fullWidth: Bool = false) -> some View {
        Button {
            settle(participant)
        } label: {
            Group {
                if settlingUserId == participant.userId {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Mark Settled")
                        .font(fullWidth ? .mndTextAction : .mndStatusLabel)
                }
            }
            .foregroundStyle(.white)
            .padding(.vertical, fullWidth ? 10 : 6)
            .padding(.horizontal, fullWidth ? 12 : 10)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background(RoundedRectangle(cornerRadius: fullWidth ? 8 : 4).fill(Color.mndBlue))
        }
        .buttonStyle(.borderless)
        .disabled(settlingUserId != nil)
    }

    private func settle(_ participant: ExpenseParticipant) {
        settlingUserId = participant.userId
        Task {
            await authService.settleShare(expenseId: liveBundle.id, debtorUserId: participant.userId)
            settlingUserId = nil
        }
    }
}

struct AddSplitSheet: View {
    @ObservedObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    @State private var title = ""
    @State private var note = ""
    @State private var amountText = ""
    @State private var selectedUserIds: Set<String> = []
    @State private var isSaving = false

    private var amountCents: Int? {
        let trimmed = amountText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let normalized = trimmed.replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: "")
        guard let value = Double(normalized), value > 0 else { return nil }
        return Int((value * 100).rounded())
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && amountCents != nil
            && selectedUserIds.count >= 2
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    MNDTextField(label: "Title", placeholder: "e.g., Utilities", text: $title)

                    MNDTextField(label: "Note", placeholder: "Optional details", text: $note)

                    MNDTextField(
                        label: "Amount",
                        placeholder: "0.00",
                        text: $amountText,
                        keyboardType: .decimalPad
                    )

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Split between")
                            .font(.mndColumnHead)
                            .foregroundStyle(scheme == .dark ? Color.mndDarkTextSecondary : Color.mndTextSecondary)

                        ForEach(authService.householdUsers) { user in
                            roommateToggle(user)
                        }

                        Text("Select at least 2 people. Split is equal among selected.")
                            .font(.mndMeta)
                            .foregroundStyle(scheme == .dark ? Color.mndDarkTextTertiary : Color.mndTextTertiary)
                    }

                    MNDPrimaryButton(title: "Create Split", isLoading: isSaving, disabled: !canSave) {
                        save()
                    }
                }
                .padding(24)
            }
            .mondayTheme()
            .navigationTitle("Add Split")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                if selectedUserIds.isEmpty {
                    selectedUserIds = Set(authService.householdUsers.map(\.id))
                }
            }
        }
    }

    private func roommateToggle(_ user: User) -> some View {
        let isSelected = selectedUserIds.contains(user.id)
        return Button {
            if isSelected {
                selectedUserIds.remove(user.id)
            } else {
                selectedUserIds.insert(user.id)
            }
        } label: {
            HStack(spacing: 12) {
                MNDUserAvatar(user: user)
                Text(user.name)
                    .font(.mndBody)
                    .foregroundStyle(scheme == .dark ? Color.mndDarkTextPrimary : Color.mndTextPrimary)
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isSelected ? Color.mndBlue : Color.mndTextTertiary)
            }
            .padding(12)
            .background(scheme == .dark ? Color.mndNightSurface2 : Color.mndSurfaceGray)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private func save() {
        guard let cents = amountCents else { return }
        isSaving = true
        Task {
            let success = await authService.addSplitExpense(
                title: title,
                note: note,
                amountCents: cents,
                participantUserIds: Array(selectedUserIds)
            )
            isSaving = false
            if success { dismiss() }
        }
    }
}

struct SettledHistoryView: View {
    let bundles: [SplitExpenseBundle]
    let users: [User]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    private func user(for id: String) -> User? {
        users.first { $0.id == id }
    }

    var body: some View {
        NavigationStack {
            Group {
                if bundles.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 36))
                            .foregroundStyle(Color.mndTextTertiary)
                        Text("No settled splits yet")
                            .font(.mndSection)
                            .foregroundStyle(scheme == .dark ? Color.mndDarkTextSecondary : Color.mndTextSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(bundles) { bundle in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(bundle.expense.title)
                                        .font(.mndItemName)
                                        .foregroundStyle(scheme == .dark ? Color.mndDarkTextPrimary : Color.mndTextPrimary)
                                    Spacer()
                                    Text(SplitMoney.format(cents: bundle.expense.amountCents))
                                        .font(.mndItemName)
                                        .foregroundStyle(Color.mndBlue)
                                }

                                if let payer = user(for: bundle.payerId) {
                                    Text("Paid by \(payer.name)")
                                        .font(.mndMeta)
                                        .foregroundStyle(scheme == .dark ? Color.mndDarkTextSecondary : Color.mndTextSecondary)
                                }

                                if let settledAt = bundle.fullySettledAt {
                                    Text("Settled \(relativeTime(settledAt))")
                                        .font(.mndMeta)
                                        .foregroundStyle(scheme == .dark ? Color.mndDarkTextTertiary : Color.mndTextTertiary)
                                }

                                ForEach(bundle.debtors) { debtor in
                                    if let name = user(for: debtor.userId)?.name,
                                       let settledAt = debtor.settledAt {
                                        let settledBy = user(for: debtor.settledByUserId ?? "")?.name ?? "someone"
                                        Text("\(name) · \(SplitMoney.format(cents: debtor.shareCents)) · marked by \(settledBy) · \(relativeTime(settledAt))")
                                            .font(.mndMeta)
                                            .foregroundStyle(scheme == .dark ? Color.mndDarkTextTertiary : Color.mndTextTertiary)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                            .listRowBackground(scheme == .dark ? Color.mndNightSurface1 : Color.mndCanvas)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .mondayTheme()
            .navigationTitle("Settled")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func relativeTime(_ date: Date) -> String {
        StatusTime.asOf(date) ?? ""
    }
}

#Preview {
    SplitView()
}
