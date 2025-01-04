import SwiftUI
import SwiftData
import Combine

struct JournalEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var entry: JournalEntry?
    @State private var text: String = ""
    @State private var lastSavedText: String = ""
    @FocusState private var isFocused: Bool
    @Query(sort: \JournalEntry.updatedAt, order: .reverse) private var entries: [JournalEntry]
    
    // Debouncer for text changes
    @StateObject private var textDebouncer = Debouncer(delay: 0.5)
    
    private let haptics = UIImpactFeedbackGenerator(style: .medium)
    private let softHaptics = UIImpactFeedbackGenerator(style: .soft)
    
    init(entry: JournalEntry?) {
        _entry = State(initialValue: entry)
        _text = State(initialValue: entry?.text ?? "")
        _lastSavedText = State(initialValue: entry?.text ?? "")
    }
    
    var body: some View {
        TextEditor(text: $text)
            .focused($isFocused)
            .readingText()
            .tint(.accent)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .textInputAutocapitalization(.sentences)
            .autocorrectionDisabled()
            // Handle immediate text changes
            .onChange(of: text) { oldValue, newValue in
                // Only trigger debouncer if text actually changed
                if oldValue != newValue {
                    textDebouncer.input = newValue
                }
            }
            // Handle debounced text changes
            .onReceive(textDebouncer.$debouncedInput) { debouncedText in
                guard debouncedText != lastSavedText else { return }
                
                do {
                    if entry == nil {
                        softHaptics.impactOccurred(intensity: 0.5)
                        let newEntry = createNewEntry()
                        modelContext.insert(newEntry)
                        entry = newEntry
                        print("✅ Created new journal entry")
                    } else {
                        entry?.text = debouncedText
                        entry?.updatedAt = Date()
                        print("✅ Updated existing journal entry")
                    }
                    
                    try modelContext.save()
                    lastSavedText = debouncedText
                } catch {
                    print("❌ Failed to save journal entry: \(error)")
                }
            }
            .onAppear {
                haptics.prepare()
                softHaptics.prepare()
                
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(300))
                    isFocused = true
                    print("✅ Journal entry view focused")
                }
            }
            .onDisappear {
                if let entry = entry, entry.text.isEmpty {
                    print("🗑️ Deleting empty journal entry")
                    haptics.impactOccurred()
                    modelContext.delete(entry)
                    do {
                        try modelContext.save()
                        print("✅ Empty entry deleted")
                    } catch {
                        print("❌ Failed to delete empty entry: \(error)")
                    }
                }
            }
    }
    
    private func createNewEntry() -> JournalEntry {
        let newEntry = JournalEntry(text: text)
        return newEntry
    }
}

// Debouncer class to handle text changes
private class Debouncer: ObservableObject {
    @Published var input: String = ""
    @Published var debouncedInput: String = ""
    private var cancellable: AnyCancellable?
    
    init(delay: TimeInterval) {
        cancellable = $input
            .removeDuplicates()
            .debounce(for: .seconds(delay), scheduler: DispatchQueue.main)
            .sink { [weak self] value in
                self?.debouncedInput = value
            }
    }
}

#Preview {
    NavigationStack {
        JournalEntryView(entry: nil)
    }
    .modelContainer(for: JournalEntry.self, inMemory: true)
} 