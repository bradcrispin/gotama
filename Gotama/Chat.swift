import Foundation
import SwiftData

@Model
final class Chat {
    var title: String
    var createdAt: Date
    var updatedAt: Date
    @Relationship(deleteRule: .cascade) var messages: [ChatMessage]
    
    init(title: String = "New chat", createdAt: Date = Date(), updatedAt: Date = Date(), messages: [ChatMessage] = []) {
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.messages = messages
    }
} 