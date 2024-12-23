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
            ContentView(navigationPath: $navigationPath)
                .modelContainer(container)
        }
    }
}
