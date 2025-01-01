import Foundation
import SwiftData

@Model
final class Chat {
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var queuedUserMessage: String?
    @Relationship(deleteRule: .cascade, inverse: \ChatMessage.chat) var messages: [ChatMessage]
    
    init(title: String = "New chat", createdAt: Date = Date(), updatedAt: Date = Date(), queuedUserMessage: String? = nil, messages: [ChatMessage] = []) {
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.queuedUserMessage = queuedUserMessage
        self.messages = messages
        for message in messages {
            message.chat = self
        }
    }
} 