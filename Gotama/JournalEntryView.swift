import SwiftUI
import SwiftData

struct JournalEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var entry: JournalEntry?
    @State private var text: String = ""
    @FocusState private var isFocused: Bool
    @Query(sort: \JournalEntry.updatedAt, order: .reverse) private var entries: [JournalEntry]
    
    private let haptics = UIImpactFeedbackGenerator(style: .medium)
    private let softHaptics = UIImpactFeedbackGenerator(style: .soft)
    
    init(entry: JournalEntry?) {
        _entry = State(initialValue: entry)
        _text = State(initialValue: entry?.text ?? "")
    }
    
    var body: some View {
        TextEditor(text: $text)
            .focused($isFocused)
            .padding()
            .onChange(of: text) {
                if entry == nil {
                    softHaptics.impactOccurred(intensity: 0.5)
                    let newEntry = createNewEntry()
                    modelContext.insert(newEntry)
                    entry = newEntry
                } else {
                    entry?.text = text
                    entry?.updatedAt = Date()
                }
            }
            .onAppear {
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(300))
                    isFocused = true
                }
            }
            .onDisappear {
                if let entry = entry, entry.text.isEmpty {
                    haptics.impactOccurred()
                    modelContext.delete(entry)
                }
            }
    }
    
    private func createNewEntry() -> JournalEntry {
        let newEntry = JournalEntry(text: text)
        
        // Calculate streak
        if let lastEntry = entries.first {
            if lastEntry.isFromYesterday {
                newEntry.isPartOfStreak = true
                newEntry.streakDay = lastEntry.streakDay + 1
            } else if !lastEntry.isFromToday {
                newEntry.streakDay = 1
                newEntry.isPartOfStreak = true
            }
        } else {
            newEntry.streakDay = 1
            newEntry.isPartOfStreak = true
        }
        
        return newEntry
    }
}

#Preview {
    NavigationStack {
        JournalEntryView(entry: nil)
    }
    .modelContainer(for: JournalEntry.self, inMemory: true)
} 