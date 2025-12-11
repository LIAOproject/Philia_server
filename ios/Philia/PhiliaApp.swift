//
//  PhiliaApp.swift
//  Philia
//
//  AI-powered relationship management iOS client
//

import SwiftUI

@main
struct PhiliaApp: App {
    @StateObject private var authService = AuthService.shared

    init() {
        // Auto sign in with device ID on launch
        Task {
            if !AuthService.shared.isAuthenticated {
                _ = try? await AuthService.shared.signInWithDevice()
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authService)
        }
    }
}
