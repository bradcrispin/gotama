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
    @Query(sort: \JournalEntry.updatedAt, order: .reverse) private var entries: [JournalEntry]
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic
    @State private var selectedEntry: JournalEntry?
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(selection: $selectedEntry) {
                Section() {
                    if entries.isEmpty {
                        ContentUnavailableView(
                            "No journal entries yet",
                            // systemImage: "square.and.pencil",
                            systemImage: "pencil",
                            description: Text("Start writing your first entry")
                        )
                        .listRowBackground(Color.clear)
                    } else {
                        ForEach(entries) { entry in
                            NavigationLink(value: entry) {
                                JournalEntryRow(entry: entry)
                            }
                        }
                        .onDelete(perform: deleteEntries)
                    }
                } header: {
                    HStack(spacing: 16) {
                        Text("Journal")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                            .textCase(nil)
                            .padding(.leading, -16)

                        Spacer()
                        
                        Button(action: createAndOpenNewEntry) {
                            Image(systemName: "square.and.pencil")
                        }
                        .padding(.trailing, -8)
                    }
                    .padding(.vertical, 8)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Gotama")
        } detail: {
            if let selectedEntry {
                JournalEntryView(entry: selectedEntry)
            } else {
                Text("Select an entry")
            }
        }
    }
    
    private func createAndOpenNewEntry() {
        let newEntry = JournalEntry()
        modelContext.insert(newEntry)
        withAnimation {
            selectedEntry = newEntry
            columnVisibility = .detailOnly
        }
    }
    
    private func deleteEntries(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(entries[index])
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: JournalEntry.self, inMemory: true)
}
