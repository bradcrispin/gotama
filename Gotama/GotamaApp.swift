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
private let skipLaunchScreenForDevelopment = false

@main
struct GotamaApp: App {
    @State private var showIntroduction = false
    @State private var showLaunchScreen = true
    @State private var launchScreenOpacity = 0.0  // New state for launch screen fade
    @State private var navigationPath: NavigationPath
    
    init() {
        // Initialize navigation path to start with new chat
        _navigationPath = State(initialValue: NavigationPath([ChatDestination.new]))
        
        // Check if this is the first ever launch
        let isFirstEverLaunch = !UserDefaults.standard.bool(forKey: "hasLaunchedBefore")
        _showIntroduction = State(initialValue: isFirstEverLaunch)
        
        // Skip animations if configured for development
        if skipLaunchScreenForDevelopment {
            _showLaunchScreen = State(initialValue: false)
            _showIntroduction = State(initialValue: false)
        }
        
        // Initialize launch screen opacity
        _launchScreenOpacity = State(initialValue: isFirstEverLaunch ? 0.0 : 1.0)
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView(navigationPath: $navigationPath)
                    .opacity(showLaunchScreen || showIntroduction ? 0 : 1)
                
                if showLaunchScreen {
                    LaunchScreenView()
                        .opacity(launchScreenOpacity)
                        .transition(.opacity)
                }
                
                if showIntroduction {
                    IntroductionView {
                        // Mark that we've shown the introduction
                        UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
                        
                        // Transition to launch screen with fade
                        withAnimation(.easeInOut(duration: 1.0)) {
                            showIntroduction = false
                            showLaunchScreen = true
                            launchScreenOpacity = 1.0
                        }
                        
                        // Start launch screen timer after a longer delay for first launch
                        Task { @MainActor in
                            try? await Task.sleep(for: .seconds(4.0))  // Increased to allow for text fade + 2s of rotating asterisk
                            startLaunchScreenTimer()
                        }
                    }
                    .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.3), value: showLaunchScreen)
            .onAppear {
                // Only start launch screen timer if we're not showing introduction
                if !showIntroduction {
                    launchScreenOpacity = 1.0
                    startLaunchScreenTimer()
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
    
    private func startLaunchScreenTimer() {
        // Set launch state
        UserDefaults.standard.set(true, forKey: "isFirstLaunch")
        
        // Dismiss launch screen after delay
        Task { @MainActor in
            // Give time for onboarding view to initialize
            try? await Task.sleep(for: .seconds(2.0))
            
            // Fade out launch screen
            withAnimation(.easeOut(duration: 0.5)) {
                launchScreenOpacity = 0.0
                showLaunchScreen = false
            }
            
            // Clear launch state after transition is complete
            try? await Task.sleep(for: .seconds(0.5))
            UserDefaults.standard.set(false, forKey: "isFirstLaunch")
        }
    }
}
