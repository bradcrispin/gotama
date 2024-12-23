import SwiftUI

struct JournalEntryRow: View {
    let entry: JournalEntry
    
    var previewText: String {
        if entry.text.isEmpty {
            return "Click to continue"
        }
        return entry.text
            .split(separator: "\n", maxSplits: 1)[0]
            .prefix(50)
            .trimmingCharacters(in: .whitespacesAndNewlines) + "..."
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(previewText)
                .font(.headline)
            Text(entry.createdAt, format: .dateTime.month().day().year())
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 4)
    }
} 