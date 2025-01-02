//
//  ContentView.swift
//  Gotama
//
//  Created by Brad Crispin on 12/22/24.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var navigationPath: NavigationPath
    @Query(sort: \JournalEntry.updatedAt, order: .reverse) private var entries: [JournalEntry]
    @Query(sort: \Chat.updatedAt, order: .reverse) private var chats: [Chat]
    @State private var isSettingsPresented = false
    @State private var isChatSectionExpanded = true
    @Query private var settings: [Settings]
    
    private let haptics = UIImpactFeedbackGenerator(style: .medium)
    private let softHaptics = UIImpactFeedbackGenerator(style: .soft)
    
    private var currentStreak: Int {
        guard !entries.isEmpty else { return 0 }
        
        // Check if there's an entry today
        if !entries.contains(where: { $0.isFromToday }) {
            return 0
        }
        
        // Count consecutive days
        var streak = 1
        var currentDate = Calendar.current.startOfDay(for: Date())
        
        while true {
            currentDate = Calendar.current.date(byAdding: .day, value: -1, to: currentDate)!
            let hasEntry = entries.contains { entry in
                Calendar.current.isDate(entry.createdAt, inSameDayAs: currentDate)
            }
            if hasEntry {
                streak += 1
            } else {
                break
            }
        }
        
        return streak
    }
    
    // Unused
    private var streakMessage: String {
        if entries.isEmpty {
            return "Journal your practice to change your life"
        }
        
        if let latest = entries.first {
            if latest.isFromToday {
                if currentStreak > 1 {
                    return "\(currentStreak) days"
                } else {
                    return "The training is to pay attention"
                }
            } else {
                return "Training becomes habit"
            }
        }
        
        return ""
    }
    
    private var showLeafIcon: Bool {
        currentStreak >= 3
    }
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                List {
                    if let settings = settings.first, !settings.firstName.isEmpty {
                                                
                        // Mindfulness Section
                        if settings.mindfulnessBellEnabled {
                            Section {
                                NavigationLink(value: MindfulnessDestination.bell) {
                                    Label("Bell", systemImage: "bell.badge")
                                        .padding(.vertical, 12)
                                        .imageScale(.small)
                                }
                            } header: {
                                HStack {
                                    Text("Mindfulness")
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.primary)
                                        .textCase(nil)
                                        .padding(.leading, -16)
                                    
                                    Spacer()
                                }
                                .padding(.vertical, 8)
                            }
                        }
                        
                        if settings.meditationBellEnabled || !settings.anthropicApiKey.isEmpty {
                            // Meditation Section
                            Section {
                                if settings.meditationBellEnabled {
                                    NavigationLink(value: MeditationDestination.bell) {
                                        Label("Solo", systemImage: "bell")
                                            .padding(.vertical, 12)
                                            .imageScale(.small)
                                    }
                                }
                                
                                // Only show guided meditation if API key is present
                                if !settings.anthropicApiKey.isEmpty {
                                    NavigationLink(value: MeditationDestination.guided) {
                                        Label {
                                            Text("Guided")
                                        } icon: {
                                            Image(systemName: "asterisk")
                                                .rotationEffect(.degrees(45))
                                                .imageScale(.large)
                                        }
                                        .padding(.vertical, 12)
                                    }
                                }
                            } header: {
                                HStack {
                                    Text("Meditate")
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.primary)
                                        .textCase(nil)
                                        .padding(.leading, -16)
                                    
                                    Spacer()
                                }
                                .padding(.vertical, 8)
                            }
                        }
                        
                        // Journal Section
                        if settings.journalEnabled {
                            Section {
                                ForEach(entries) { entry in
                                    NavigationLink(value: JournalDestination.existing(entry)) {
                                        Label {
                                            JournalEntryRow(entry: entry)
                                        } icon: {
                                            Image(systemName: "text.book.closed")
                                                .imageScale(.large)
                                        }
                                    }
                                }
                                .onDelete(perform: deleteEntries)
                            } header: {
                                HStack {
                                    Text("Journal")
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.primary)
                                        .textCase(nil)
                                        .padding(.leading, -16)
                                    
                                    if currentStreak > 1 {
                                        Text("(\(currentStreak) days in a row)")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                    
                                    if showLeafIcon {
                                        Image(systemName: "leaf.fill")
                                            .foregroundStyle(.accent.opacity(0.8))
                                            .font(.caption)
                                    }
                                    
                                    Spacer()
                                    
                                    if entries.isEmpty {
                                        Button(action: createAndOpenNewEntry) {
                                            Image(systemName: "square.and.pencil")
                                                .font(.title3)
                                                .padding(.trailing, -16)
                                        }
                                    }
                                }
                                .padding(.vertical, 8)
                            }
                        }
                    }
                    
                    // Chats Section
                    Section {
                        ForEach(chats) { chat in
                            NavigationLink(value: ChatDestination.existing(chat)) {
                                ChatRow(chat: chat)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .onDelete(perform: deleteChats)
                    } header: {
                        HStack {
                            Text("Chats")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
                                .textCase(nil)
                                .padding(.leading, -16)
                            
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    }
                }
                .listStyle(.insetGrouped)
                .navigationTitle("Home")
                .navigationDestination(for: ChatDestination.self) { destination in
                    switch destination {
                    case .existing(let chat):
                        ChatView(chat: chat)
                            .id(chat.id)
                    case .new:
                        ChatView(chat: nil)
                            .id(UUID())
                    }
                }
                .navigationDestination(for: JournalDestination.self) { destination in
                    switch destination {
                    case .existing(let entry):
                        JournalEntryView(entry: entry)
                    case .new:
                        JournalEntryView(entry: nil)
                            .id(UUID())
                    }
                }
                .navigationDestination(for: MeditationDestination.self) { destination in
                    switch destination {
                    case .bell:
                        MeditationBellView()
                    case .guided:
                        ChatView(chat: createGuidedMeditationChat())
                    }
                }
                .navigationDestination(for: MindfulnessDestination.self) { destination in
                    switch destination {
                    case .bell:
                        MindfulnessBellView()
                    }
                }
                .toolbar {
                    ToolbarItem(id: "settingsButton", placement: .topBarTrailing) {
                        Button {
                            isSettingsPresented = true
                        } label: {
                            if let firstName = settings.first?.firstName, !firstName.isEmpty {
                                Text(firstName.prefix(1))
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                    .frame(width: 32, height: 32)
                                    .background(.accent)
                                    .clipShape(Circle())
                            } else {
                                Image(systemName: "person.crop.circle")
                                    .font(.title3)
                            }
                        }
                    }
                }
                .sheet(isPresented: $isSettingsPresented) {
                    SettingsView()
                }
                
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: createAndOpenNewChat) {
                            Image(systemName: "asterisk")
                                .font(.title2)
                                .foregroundStyle(.white)
                                .rotationEffect(.degrees(45))
                                .frame(width: 56, height: 56)
                                .background(.accent)
                                .clipShape(Circle())
                                .shadow(radius: 4, y: 2)
                        }
                        .padding(.trailing, 16)
                        .padding(.bottom, 16)
                    }
                }
            }
        }
    }
    
    private func createAndOpenNewEntry() {
        haptics.impactOccurred()
        withAnimation {
            navigationPath.append(JournalDestination.new)
        }
    }
    
    private func deleteEntries(offsets: IndexSet) {
        haptics.impactOccurred()
        withAnimation {
            for index in offsets {
                modelContext.delete(entries[index])
            }
        }
    }
    
    private func createAndOpenNewChat() {
        haptics.impactOccurred()
        withAnimation {
            navigationPath.append(ChatDestination.new)
        }
    }
    
    private func deleteChats(offsets: IndexSet) {
        haptics.impactOccurred()
        print("🗑️ Deleting chats at offsets: \(offsets)")
        withAnimation(.easeInOut(duration: 0.3)) {
            for index in offsets {
                print("🗑️ Deleting chat: \(chats[index].id)")
                modelContext.delete(chats[index])
            }
        }
    }
    
    private func createGuidedMeditationChat() -> Chat {
        let chat = Chat()
        chat.queuedUserMessage = "Please guide me in meditation for 5 minutes"
        return chat
    }
}

struct ChatRow: View {
    let chat: Chat
    
    var body: some View {
        Text(chat.title)
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.trailing, 8)
            .padding(.vertical, 12)
    }
}

struct JournalEntryRow: View {
    let entry: JournalEntry
    
    var previewText: String {
        if entry.text.isEmpty {
            return "New entry"
        }
        let firstLine = entry.text.split(separator: "\n", maxSplits: 1)[0]
        return String(firstLine)
    }
    
    private var dateDescription: String {
        if entry.isFromToday {
            return "Today"
        } else if entry.isFromYesterday {
            return "Yesterday"
        } else {
            return entry.updatedAt.formatted(.dateTime.month().day())
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(previewText)
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundStyle(.primary)
                .font(.body)
            
            Text(dateDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
                // .textCase(.uppercase)
        }
        .padding(.vertical, 8)
    }
} 

#Preview {
    ContentView(navigationPath: .constant(NavigationPath()))
        .modelContainer(for: JournalEntry.self, inMemory: true)
}

enum ChatDestination: Hashable {
    case existing(Chat)
    case new
}

enum JournalDestination: Hashable {
    case existing(JournalEntry)
    case new
}

enum MeditationDestination: Hashable {
    case bell
    case guided
}

enum MindfulnessDestination: Hashable {
    case bell
}
