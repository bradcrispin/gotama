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
    @Query(sort: \Chat.updatedAt, order: .reverse) private var chats: [Chat]
    @State private var isSettingsPresented = false
    @State private var isChatSectionExpanded = true
    @Query private var settings: [Settings]
    @State private var journal: JournalEntry?
    
    // MARK: - Configuration
    private let sectionVerticalPadding: CGFloat = 2  // Controls padding for section headers
    private let navigationLinkVerticalPadding: CGFloat = 8  // Controls padding for navigation links
    
    private let haptics = UIImpactFeedbackGenerator(style: .medium)
    private let softHaptics = UIImpactFeedbackGenerator(style: .soft)
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                List {
                    if let settings = settings.first, !settings.firstName.isEmpty {
                                                
                        // Mindfulness Section
                        if settings.mindfulnessBellEnabled || settings.journalEnabled {
                            Section {
                                if settings.mindfulnessBellEnabled {
                                    NavigationLink(value: MindfulnessDestination.bell) {
                                        Label("Bell", systemImage: "bell.badge")
                                                .padding(.vertical, navigationLinkVerticalPadding)
                                                .imageScale(.small)
                                    }
                                }
                                if settings.journalEnabled {
                                    NavigationLink(value: JournalDestination.existing(journal ?? JournalEntry())) {
                                            Label {
                                                if let entry = journal {
                                                    JournalEntryRow(entry: entry)
                                                } else {
                                                    Text("Loading...")
                                                }
                                            } icon: {
                                                Image(systemName: "text.book.closed")
                                                    .imageScale(.large)
                                            }
                                        }
                                }
                            } header: {
                                HStack {
                                    Text("Mindful")
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.primary)
                                        .textCase(nil)
                                        .padding(.leading, -16)
                                    
                                    Spacer()
                                }
                                .padding(.vertical, sectionVerticalPadding)
                            }
                        }
                        
                        if settings.meditationTimerEnabled || !settings.anthropicApiKey.isEmpty {
                            // Meditation Section
                            Section {
                                if settings.meditationTimerEnabled {
                                    NavigationLink(value: MeditationDestination.bell) {
                                        Label("Timer", systemImage: "timer")
                                            .padding(.vertical, navigationLinkVerticalPadding)
                                            .imageScale(.small)
                                    }
                                }
                                
                                // Only show guided meditation if API key is present
                                // if !settings.anthropicApiKey.isEmpty {
                                //     NavigationLink(value: MeditationDestination.guided) {
                                //         Label {
                                //             Text("Guided")
                                //         } icon: {
                                //             Image(systemName: "asterisk")
                                //                 .rotationEffect(.degrees(45))
                                //                 .imageScale(.large)
                                //         }
                                //         .padding(.vertical, navigationLinkVerticalPadding)
                                //     }
                                // }
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
                                .padding(.vertical, sectionVerticalPadding)
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
                        .padding(.vertical, sectionVerticalPadding)
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
                    }
                }
                .navigationDestination(for: MeditationDestination.self) { destination in
                    switch destination {
                    case .bell:
                        MeditationTimerView()
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
        .task {
            do {
                journal = try JournalEntry.getOrCreate(modelContext: modelContext)
            } catch {
                print("❌ Error loading journal: \(error)")
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
            Text("Journal")
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundStyle(.primary)
                .font(.body)
            
            // Text(dateDescription)
            //     .font(.caption)
            //     .foregroundStyle(.secondary)
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
}

enum MeditationDestination: Hashable {
    case bell
    case guided
}

enum MindfulnessDestination: Hashable {
    case bell
}
