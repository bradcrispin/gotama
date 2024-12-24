//
//  GotamaApp.swift
//  Gotama
//
//  Created by Brad Crispin on 12/22/24.
//

import SwiftUI
import SwiftData

@main
struct GotamaApp: App {
    let container: ModelContainer
    @State private var navigationPath: NavigationPath
    @State private var isShowingLaunchScreen = true
    
    init() {
        do {
            container = try ModelContainer(
                for: Chat.self, JournalEntry.self, Settings.self,
                migrationPlan: nil,
                configurations: ModelConfiguration(isStoredInMemoryOnly: false)
            )
            _navigationPath = State(initialValue: NavigationPath([ChatDestination.new]))
        } catch {
            fatalError("Could not configure SwiftData container: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView(navigationPath: $navigationPath)
                    .modelContainer(container)
                
                if isShowingLaunchScreen {
                    LaunchScreenView()
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation(.easeOut(duration: 0.5)) {
                        isShowingLaunchScreen = false
                    }
                }
            }
        }
    }
}
