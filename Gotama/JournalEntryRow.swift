import SwiftUI

struct JournalEntryRow: View {
    let entry: JournalEntry
    
    var previewText: String {
        if entry.text.isEmpty {
            return "Click to continue"
        }
        let firstLine = entry.text.split(separator: "\n", maxSplits: 1)[0]
        let truncated = firstLine.prefix(50)
        return truncated.trimmingCharacters(in: .whitespacesAndNewlines) + 
               (truncated.count < firstLine.count ? "..." : "")
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