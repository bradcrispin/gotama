import Foundation
import SwiftData

@Model
final class JournalEntry {
    var text: String
    var createdAt: Date
    var updatedAt: Date
    
    // Streak-related properties
    var isPartOfStreak: Bool
    var streakDay: Int
    
    init(text: String = "", createdAt: Date = Date(), updatedAt: Date = Date(), isPartOfStreak: Bool = false, streakDay: Int = 0) {
        self.text = text
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isPartOfStreak = isPartOfStreak
        self.streakDay = streakDay
    }
    
    // Helper function to check if entry was created today
    var isFromToday: Bool {
        Calendar.current.isDateInToday(createdAt)
    }
    
    // Helper function to check if entry was created yesterday
    var isFromYesterday: Bool {
        Calendar.current.isDateInYesterday(createdAt)
    }
} 