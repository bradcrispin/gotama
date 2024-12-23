import Foundation
import SwiftData

@Model
final class ChatMessage {
    var role: String
    var content: String
    var createdAt: Date
    var error: String?
    var isTyping: Bool?
    var chat: Chat?
    
    init(role: String = "user", content: String = "", createdAt: Date = Date(), error: String? = nil, isTyping: Bool? = nil) {
        self.role = role
        self.content = content
        self.createdAt = createdAt
        self.error = error
        self.isTyping = isTyping
    }
} 