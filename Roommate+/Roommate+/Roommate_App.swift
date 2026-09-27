//
//  Roommate_App.swift
//  Roommate+
//
//  Created by Michael Lu on 6/30/26.
//

import SwiftUI

@main
struct Roommate_App: App {
    @StateObject private var authService = AuthService.shared
    @StateObject private var appearance = AppearanceManager.shared

    var body: some Scene {
        WindowGroup {
            Group {
                if authService.isRestoring {
                    RestoringView()
                } else if authService.currentHousehold != nil {
                    MainTabView()
                } else {
                    SetupHouseholdView()
                }
            }
            .mondayTheme()
            .tint(.mndBlue)
            .preferredColorScheme(appearance.mode.colorScheme)
            .task {
                await authService.restoreSession()
            }
        }
    }
}

private struct RestoringView: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 6) {
                Circle().fill(Color.mndRed).frame(width: 10, height: 10)
                Circle().fill(Color.mndOrange).frame(width: 10, height: 10)
                Circle().fill(Color.mndGreen).frame(width: 10, height: 10)
            }
            Text("Roommate+")
                .font(.mndBoardTitle)
                .foregroundStyle(scheme == .dark ? Color.mndDarkTextPrimary : Color.mndTextPrimary)
            ProgressView()
                .tint(.mndBlue)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .mondayTheme()
    }
}
