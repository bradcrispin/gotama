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
} 