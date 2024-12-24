import SwiftUI
import SwiftData

struct JournalEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var entry: JournalEntry?
    @State private var text: String = ""
    @FocusState private var isFocused: Bool
    
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
                    let newEntry = JournalEntry(text: text)
                    modelContext.insert(newEntry)
                    entry = newEntry
                } else {
                    entry?.text = text
                    entry?.updatedAt = Date()
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
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
}

#Preview {
    NavigationStack {
        JournalEntryView(entry: nil)
    }
    .modelContainer(for: JournalEntry.self, inMemory: true)
} 