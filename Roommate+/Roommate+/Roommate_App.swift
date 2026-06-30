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

    var body: some Scene {
        WindowGroup {
            if authService.currentHousehold != nil {
                GroceryListView()
            } else {
                SetupHouseholdView()
            }
        }
    }
}
