import SwiftUI

struct MainTabView: View {
    @StateObject private var authService = AuthService.shared
    @State private var realtimeService: RealtimeService?

    var body: some View {
        TabView {
            StatusView()
                .tabItem {
                    Label("Status", systemImage: "person.2.wave.2.fill")
                }

            GroceryListView()
                .tabItem {
                    Label("Grocery", systemImage: "cart.fill")
                }

            SplitView()
                .tabItem {
                    Label("Split", systemImage: "dollarsign.circle.fill")
                }

            HouseholdInfoView()
                .tabItem {
                    Label("Info", systemImage: "info.circle.fill")
                }
        }
        .tint(.mndBlue)
        .task(id: authService.currentHousehold?.id) {
            await authService.fetchHouseholdData()
            startRealtime()
        }
        // Fallback if Realtime isn't enabled yet — keeps phones roughly in sync.
        .task(id: authService.currentHousehold?.id) {
            guard authService.currentHousehold?.id != nil else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(20))
                guard !Task.isCancelled else { return }
                await authService.fetchHouseholdData()
            }
        }
        .onDisappear {
            realtimeService?.stop()
            realtimeService = nil
        }
    }

    private func startRealtime() {
        guard let householdId = authService.currentHousehold?.id else {
            realtimeService?.stop()
            realtimeService = nil
            return
        }

        realtimeService?.stop()
        let service = RealtimeService(supabase: authService.supabase)
        realtimeService = service
        service.start(householdId: householdId) {
            await authService.fetchHouseholdData()
        }
    }
}

#Preview {
    MainTabView()
        .mondayTheme()
}
