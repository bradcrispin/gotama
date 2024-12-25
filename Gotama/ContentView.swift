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
    @State private var isChatSectionExpanded = false
    @Query private var settings: [Settings]
    
    private let haptics = UIImpactFeedbackGenerator(style: .medium)
    private let softHaptics = UIImpactFeedbackGenerator(style: .soft)
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                List {
                    // Chats Section
                    Section {
                        if isChatSectionExpanded {
                            ForEach(chats) { chat in
                                NavigationLink(value: ChatDestination.existing(chat)) {
                                    ChatRow(chat: chat)
                                }
                            }
                            .onDelete(perform: deleteChats)
                        }
                    } header: {
                        Button {
                            withAnimation(.spring(duration: 0.3)) {
                                isChatSectionExpanded.toggle()
                                softHaptics.impactOccurred()
                            }
                        } label: {
                            HStack {
                                Text("Chats")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.primary)
                                    .textCase(nil)
                                    .padding(.leading, -16)
                                
                                if !chats.isEmpty {
                                    Text("(\(chats.count))")
                                        .foregroundStyle(.primary.opacity(0.7))
                                        .font(.subheadline)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.primary.opacity(0.7))
                                    .rotationEffect(.degrees(isChatSectionExpanded ? 90 : 0))
                                    .padding(.trailing, -8)
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.vertical, 8)
                    }
                    
                    // Journal Section
                    Section {
                        ForEach(entries) { entry in
                            NavigationLink(value: JournalDestination.existing(entry)) {
                                JournalEntryRow(entry: entry)
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

                            Spacer()
                            
                            Button(action: createAndOpenNewEntry) {
                                Image(systemName: "square.and.pencil")
                                    .font(.title3)
                                    .padding(.trailing, -16)
                            }
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
                            Image(systemName: "plus.message.fill")
                                .font(.title2)
                                .foregroundStyle(.white)
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
}

struct ChatRow: View {
    let chat: Chat
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ViewThatFits {
                // Try to fit the full title
                Text(chat.title)
                    .fontWeight(.medium)
                    .fixedSize(horizontal: false, vertical: true)
                
                // If it doesn't fit, show truncated with ellipsis
                Text(chat.title)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .truncationMode(.tail)
            }
        }
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
