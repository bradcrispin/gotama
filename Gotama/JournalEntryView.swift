import SwiftUI

struct JournalEntryView: View {
    @Bindable var entry: JournalEntry
    @FocusState private var isFocused: Bool
    
    var body: some View {
        TextEditor(text: $entry.text)
            .focused($isFocused)
            .padding()
            .onChange(of: entry.text) {
                entry.updatedAt = Date()
            }
            .onAppear {
                // Only focus if it's a new entry (empty text)
                if entry.text.isEmpty {
                    // Small delay to ensure the view is fully loaded
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        isFocused = true
                    }
                }
            }
    }
} 