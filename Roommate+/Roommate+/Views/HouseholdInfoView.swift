import SwiftUI
import PhotosUI

struct HouseholdInfoView: View {
    @StateObject private var authService = AuthService.shared
    @State private var showingJoinCode = false
    @State private var joinCode = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var isUploadingPhoto = false
    @State private var venmoUsername = ""
    @State private var zellePhone = ""
    @State private var isSavingPayment = false

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

                    if let success = authService.successMessage {
                        MNDSuccessBanner(message: success) {
                            authService.successMessage = nil
                        }
                    }

                    householdCard
                    paymentSection
                    roommatesSection
                    actionsSection
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
            .navigationTitle("Info")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingJoinCode) {
                JoinCodeSheet(joinCode: $joinCode, authService: authService)
                    .presentationDetents([.medium])
            }
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                uploadPhoto(from: item)
            }
            .onAppear {
                syncPaymentFields()
            }
            .onChange(of: authService.currentUser?.id) { _, _ in
                syncPaymentFields()
            }
        }
    }

    private func syncPaymentFields() {
        venmoUsername = authService.currentUser?.venmoUsername ?? ""
        zellePhone = authService.currentUser?.zellePhone ?? ""
    }

    private var paymentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Payment Info")
                .font(.mndColumnHead)
                .foregroundStyle(scheme == .dark ? Color.mndDarkTextSecondary : Color.mndTextSecondary)

            Text("Used when roommates settle splits via Venmo or Zelle.")
                .font(.mndMeta)
                .foregroundStyle(scheme == .dark ? Color.mndDarkTextTertiary : Color.mndTextTertiary)

            VStack(spacing: 14) {
                MNDTextField(
                    label: "Venmo username",
                    placeholder: "e.g., alexr",
                    text: $venmoUsername
                )

                MNDTextField(
                    label: "Zelle phone number",
                    placeholder: "(555) 123-4567",
                    text: $zellePhone,
                    keyboardType: .phonePad
                )

                MNDPrimaryButton(title: "Save Payment Info", isLoading: isSavingPayment) {
                    savePaymentInfo()
                }
            }
            .padding(16)
            .background(scheme == .dark ? Color.mndNightSurface1 : Color.mndSurfaceGray)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func savePaymentInfo() {
        isSavingPayment = true
        Task {
            _ = await authService.updatePaymentInfo(
                venmoUsername: venmoUsername,
                zellePhone: zellePhone
            )
            isSavingPayment = false
        }
    }

    private var householdCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let household = authService.currentHousehold {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.mndBrightBlue)
                        .frame(width: 12, height: 12)
                    Text(household.name)
                        .font(.mndSection)
                        .foregroundStyle(scheme == .dark ? Color.mndDarkTextPrimary : Color.mndTextPrimary)
                }
            }

            if let user = authService.currentUser {
                HStack(spacing: 14) {
                    profilePhotoPicker(for: user)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(user.name)
                            .font(.mndItemName)
                            .foregroundStyle(scheme == .dark ? Color.mndDarkTextPrimary : Color.mndTextPrimary)
                        Text("Rotation #\(user.rotationOrder)")
                            .font(.mndMeta)
                            .foregroundStyle(scheme == .dark ? Color.mndDarkTextSecondary : Color.mndTextSecondary)
                        Text("Tap photo to change")
                            .font(.mndMeta)
                            .foregroundStyle(scheme == .dark ? Color.mndDarkTextTertiary : Color.mndTextTertiary)
                    }

                    Spacer()

                    if authService.isCurrentUserPaused {
                        MNDStatusCell(label: "Paused", color: .mndWarning)
                    }
                }

                if user.avatarUrl != nil {
                    Button("Remove Photo") {
                        Task { await authService.removeProfilePhoto() }
                    }
                    .font(.mndTextAction)
                    .foregroundStyle(Color.mndRed)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(scheme == .dark ? Color.mndNightSurface1 : Color.mndSurfaceGray)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var roommatesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Roommates")
                .font(.mndColumnHead)
                .foregroundStyle(scheme == .dark ? Color.mndDarkTextSecondary : Color.mndTextSecondary)

            VStack(spacing: 0) {
                ForEach(authService.householdUsers) { user in
                    HStack(spacing: 10) {
                        MNDUserAvatar(user: user)
                        Text(user.name)
                            .font(.mndItemName)
                            .foregroundStyle(scheme == .dark ? Color.mndDarkTextPrimary : Color.mndTextPrimary)
                        Spacer()
                        if user.isPaused {
                            MNDStatusCell(label: "Paused", color: .mndWarning)
                        } else {
                            Text("#\(user.rotationOrder)")
                                .font(.mndMeta)
                                .foregroundStyle(scheme == .dark ? Color.mndDarkTextTertiary : Color.mndTextTertiary)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)

                    if user.id != authService.householdUsers.last?.id {
                        Rectangle()
                            .fill(scheme == .dark ? Color.mndNightDivider : Color.mndDivider)
                            .frame(height: 1)
                            .padding(.leading, 48)
                    }
                }
            }
            .background(scheme == .dark ? Color.mndNightSurface1 : Color.mndSurfaceGray)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var actionsSection: some View {
        VStack(spacing: 10) {
            if authService.isCurrentUserPaused {
                MNDPrimaryButton(title: "I'm Back — Resume My Turns") {
                    Task { await authService.resumeMyTurns() }
                }
            } else {
                MNDSecondaryButton(title: "Pause My Turns (away)", icon: "pause.circle") {
                    pauseTurns()
                }
            }

            MNDSecondaryButton(title: "Share Join Code", icon: "link") {
                showingJoinCode = true
            }

            MNDSecondaryButton(title: "Leave Household", icon: "door.left.hand.open", tint: .mndError) {
                Task { await authService.leaveHousehold() }
            }
        }
    }

    private func pauseTurns() {
        Task {
            let until = Date().addingTimeInterval(3 * 24 * 60 * 60)
            await authService.pauseMyTurn(until: until)
        }
    }

    @ViewBuilder
    private func profilePhotoPicker(for user: User) -> some View {
        PhotosPicker(selection: $photoItem, matching: .images) {
            ZStack(alignment: .bottomTrailing) {
                MNDUserAvatar(user: user, size: 56)
                    .overlay {
                        if isUploadingPhoto {
                            Circle()
                                .fill(Color.black.opacity(0.45))
                            ProgressView()
                                .tint(.white)
                        }
                    }

                Image(systemName: "camera.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(5)
                    .background(Circle().fill(Color.mndBlue))
                    .offset(x: 2, y: 2)
            }
        }
        .buttonStyle(.plain)
        .disabled(isUploadingPhoto)
    }

    private func uploadPhoto(from item: PhotosPickerItem) {
        isUploadingPhoto = true
        Task {
            defer {
                isUploadingPhoto = false
                photoItem = nil
            }
            guard let data = try? await item.loadTransferable(type: Data.self) else {
                authService.errorMessage = "Could not load that photo."
                return
            }
            _ = await authService.uploadProfilePhoto(data)
        }
    }
}

#Preview {
    HouseholdInfoView()
}
