import Foundation
import SwiftData

@Model
final class JournalEntry {
    var text: String
    var createdAt: Date
    var updatedAt: Date
    
    init(text: String = "", createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.text = text
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    // Helper function to check if entry was created today
    var isFromToday: Bool {
        Calendar.current.isDateInToday(createdAt)
    }
    
    // Helper function to check if entry was created yesterday
    var isFromYesterday: Bool {
        Calendar.current.isDateInYesterday(createdAt)
    }
    
    // MARK: - Singleton Access
    
    /// Gets the single journal entry or creates it if it doesn't exist
    /// - Parameter modelContext: The SwiftData model context
    /// - Returns: The single journal entry instance
    /// - Throws: If there's an error accessing or creating the journal entry
    @MainActor
    static func getOrCreate(modelContext: ModelContext) throws -> JournalEntry {
        let descriptor = FetchDescriptor<JournalEntry>()
        let entries = try modelContext.fetch(descriptor)
        
        if let existingEntry = entries.first {
            // If there are multiple entries (shouldn't happen), delete extras
            if entries.count > 1 {
                print("⚠️ Found multiple journal entries, cleaning up extras")
                for extraEntry in entries.dropFirst() {
                    modelContext.delete(extraEntry)
                }
            }
            return existingEntry
        }
        
        // Create new entry if none exists
        let newEntry = JournalEntry()
        modelContext.insert(newEntry)
        return newEntry
    }
} 