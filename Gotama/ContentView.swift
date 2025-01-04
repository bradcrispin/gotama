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
    
    // Section configuration
    private let sectionVerticalPadding: CGFloat = 4
    
    // List item configuration
    private let listItemVerticalPadding: CGFloat = 11  // Standard iOS list item padding
    private let listItemHorizontalPadding: CGFloat = 4 // Fine-tune horizontal alignment
    private let listItemIconSpacing: CGFloat = 12      // Space between icon and text
    private let listItemRowSpacing: CGFloat = 4        // Space between rows in multi-line items
    
    private let haptics = UIImpactFeedbackGenerator(style: .medium)
    private let softHaptics = UIImpactFeedbackGenerator(style: .soft)
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                List {
                    if let settings = settings.first, !settings.firstName.isEmpty {
                        // Tools Section
                        if settings.mindfulnessBellEnabled || settings.journalEnabled || settings.meditationTimerEnabled {
                            Section {
                                if settings.mindfulnessBellEnabled {
                                    NavigationLink(value: MindfulnessDestination.bell) {
                                        Label {
                                            Text("Bell")
                                                .navigationRowText()
                                        } icon: {
                                            Image(systemName: settings.mindfulnessBellIsScheduled ? "bell.badge" : "bell.slash")
                                                .imageScale(.medium)
                                        }
                                        .padding(.vertical, listItemVerticalPadding)
                                        .padding(.horizontal, listItemHorizontalPadding)
                                        .contentTransition(.symbolEffect(.replace))
                                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: settings.mindfulnessBellIsScheduled)
                                    }
                                }
                                if settings.journalEnabled {
                                    NavigationLink(value: JournalDestination.existing(journal ?? JournalEntry())) {
                                        Label {
                                            if let entry = journal {
                                                JournalEntryRow(entry: entry)
                                            } else {
                                                Text("Loading...")
                                                    .navigationRowText()
                                            }
                                        } icon: {
                                            Image(systemName: "text.book.closed")
                                                .imageScale(.medium)
                                        }
                                        .padding(.horizontal, listItemHorizontalPadding)
                                    }
                                }
                                if settings.meditationTimerEnabled {
                                    NavigationLink(value: MeditationDestination.timer) {
                                        Label {
                                            Text("Timer")
                                                .navigationRowText()
                                        } icon: {
                                            Image(systemName: "timer")
                                                .imageScale(.medium)
                                        }
                                        .padding(.vertical, listItemVerticalPadding)
                                        .padding(.horizontal, listItemHorizontalPadding)
                                    }
                                }
                            } header: {
                                HStack {
                                    Text("Tools")
                                        .sectionHeaderText()
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
                                    .padding(.horizontal, listItemHorizontalPadding)
                            }
                        }
                        .onDelete(perform: deleteChats)
                    } header: {
                        HStack {
                            Text("Gotama")
                                .sectionHeaderText()
                                .textCase(nil)
                                .padding(.leading, -16)
                            Spacer()
                        }
                        .padding(.vertical, sectionVerticalPadding)
                    }
                }
                .listStyle(.insetGrouped)
                .navigationTitle("Studio")
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
                    case .timer:
                        MeditationTimerView()
                    // case .guided:
                    //     ChatView(chat: createGuidedMeditationChat())
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
    @Environment(\.listItemVerticalPadding) private var verticalPadding
    let chat: Chat
    
    var body: some View {
        Text(chat.title)
            .navigationRowText()
            .padding(.vertical, verticalPadding)
    }
}

struct JournalEntryRow: View {
    @Environment(\.listItemRowSpacing) private var rowSpacing
    @Environment(\.listItemVerticalPadding) private var verticalPadding
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
        VStack(alignment: .leading, spacing: rowSpacing) {
            Text("Journal")
                .navigationRowText()
            
            // Uncomment if you want to show the date
            // Text(dateDescription)
            //     .navigationMetadataText()
        }
        .padding(.vertical, verticalPadding)
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
    case timer
    // case guided
}

enum MindfulnessDestination: Hashable {
    case bell
}

// Add environment values for consistent padding across views
private struct ListItemVerticalPaddingKey: EnvironmentKey {
    static let defaultValue: CGFloat = 11
}

private struct ListItemRowSpacingKey: EnvironmentKey {
    static let defaultValue: CGFloat = 4
}

extension EnvironmentValues {
    var listItemVerticalPadding: CGFloat {
        get { self[ListItemVerticalPaddingKey.self] }
        set { self[ListItemVerticalPaddingKey.self] = newValue }
    }
    
    var listItemRowSpacing: CGFloat {
        get { self[ListItemRowSpacingKey.self] }
        set { self[ListItemRowSpacingKey.self] = newValue }
    }
}
