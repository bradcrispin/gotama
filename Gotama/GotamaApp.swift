//
//  GotamaApp.swift
//  Gotama
//
//  Created by Brad Crispin on 12/22/24.
//

import SwiftUI
import SwiftData

// MARK: - Development Configuration
/// Set to true to skip launch screen animations during development
private let skipLaunchScreenForDevelopment = true

@main
struct GotamaApp: App {
    @State private var showLaunchScreen = true
    @State private var navigationPath: NavigationPath
    
    init() {
        // Initialize navigation path to start with new chat
        _navigationPath = State(initialValue: NavigationPath([ChatDestination.new]))
        
        // Skip launch screen if configured for development
        if skipLaunchScreenForDevelopment {
            _showLaunchScreen = State(initialValue: false)
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView(navigationPath: $navigationPath)
                    .opacity(showLaunchScreen ? 0 : 1)
                
                if showLaunchScreen {
                    LaunchScreenView()
                        .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.3), value: showLaunchScreen)
            .onAppear {
                // Set launch state
                UserDefaults.standard.set(true, forKey: "isFirstLaunch")
                
                // Dismiss launch screen after delay
                Task { @MainActor in
                    // Give time for onboarding view to initialize
                    try? await Task.sleep(for: .seconds(2.0))
                    
                    // Fade out launch screen
                    withAnimation(.easeOut(duration: 0.5)) {
                        showLaunchScreen = false
                    }
                    
                    // Clear launch state after transition is complete
                    try? await Task.sleep(for: .seconds(0.5))
                    UserDefaults.standard.set(false, forKey: "isFirstLaunch")
                }
            }
        }
        .modelContainer(for: [
            Settings.self,
            Chat.self,
            ChatMessage.self,
            JournalEntry.self
        ])
    }
}
