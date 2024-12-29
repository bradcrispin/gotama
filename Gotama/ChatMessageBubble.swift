import SwiftUI
import SwiftData

/// A view component that displays a single message in the chat interface.
/// Handles both user and assistant messages with different styling and interaction options.
///
/// Features:
/// - Different styling for user and assistant messages
/// - Context menu for copying, editing, and deleting messages
/// - Error display with retry option
/// - Confirmation buttons for yes/no responses
/// - Thinking state animation
///
/// Usage:
/// ```swift
/// ChatMessageBubble(
///     message: chatMessage,
///     onRetry: { await retryMessage() },
///     showError: true,
///     messageText: $messageText,
///     showConfirmation: false
/// )
/// ```
struct ChatMessageBubble: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    
    let message: ChatMessage
    var onRetry: (() async -> Void)?
    let showError: Bool
    @Binding var messageText: String
    let showConfirmation: Bool
    
    @State private var showCopied = false
    @State private var showDeleteConfirmation = false
    @State private var showEditConfirmation = false
    
    var body: some View {
        HStack {
            if message.role == "user" {
                Spacer()
            }
            
            VStack(alignment: message.role == "user" ? .trailing : .leading, spacing: 8) {
                if message.isThinking == true {
                    ChatThinkingIndicator()
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                } else {
                    Text(message.content)
                        .textSelection(.enabled)
                        .padding(.vertical, 8)
                        .padding(.horizontal, message.role == "user" ? 12 : 16)
                        .contextMenu(menuItems: {
                            Button {
                                UIPasteboard.general.string = message.content
                            } label: {
                                Label("Copy", systemImage: "doc.on.doc")
                            }
                            
                            if message.role == "user" {
                                Button {
                                    editMessage()
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                
                                Button(role: .destructive) {
                                    deleteMessageAndFollowing()
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        })
                    
                    if showConfirmation {
                        HStack(spacing: 12) {
                            Button {
                                messageText = "Yes"
                            } label: {
                                Text("Yes")
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.accent)
                                    .foregroundColor(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                            }
                            
                            Button {
                                messageText = "No"
                            } label: {
                                Text("No")
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color(.systemGray5))
                                    .foregroundColor(.primary)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                            }
                        }
                        .padding(.top, 4)
                    }
                }
                
                if showError, let error = message.error {
                    HStack(spacing: 8) {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        if let onRetry {
                            Button {
                                Task {
                                    await onRetry()
                                }
                            } label: {
                                Image(systemName: "arrow.clockwise")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .background(message.role == "user" ? (colorScheme == .dark ? Color(white: 0.15) : Color(white: 0.93)) : nil)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            
            if message.role == "assistant" {
                Spacer()
            }
        }
        .alert("Edit Message", isPresented: $showEditConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Edit", role: .destructive) {
                editMessage()
            }
        } message: {
            Text("Editing and resending this message will delete all messages that follow")
        }
        .alert("Delete Message", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteMessageAndFollowing()
            }
        } message: {
            Text("Deleting this message will delete all messages that follow")
        }
    }
    
    private func editMessage() {
        print("✏️ Starting message edit")
        
        // Set the message text for editing
        messageText = message.content
        print("📝 Loaded message text for editing: \(messageText)")
        
        // Check if this is the first message and update chat title
        if let chat = message.chat,
           let firstMessage = chat.messages.first,
           firstMessage.id == message.id {
            chat.title = messageText
        }
        
        // Delete this and following messages
        deleteMessageAndFollowing()
    }
    
    private func deleteMessageAndFollowing() {
        guard let chat = message.chat else {
            print("❌ Delete failed: No chat associated with message")
            return
        }
        
        // Find the index of the current message
        guard let currentIndex = chat.messages.firstIndex(where: { $0.id == message.id }) else {
            print("❌ Delete failed: Could not find message index in chat")
            return
        }
        
        print("🗑️ Deleting message at index \(currentIndex) and \(chat.messages.count - currentIndex - 1) following messages")
        
        // Get all messages from current to end
        let messagesToDelete = Array(chat.messages[currentIndex...])
        print("📝 Messages to delete: \(messagesToDelete.count)")
        
        // Remove messages from chat's messages array first
        withAnimation {
            chat.messages.removeSubrange(currentIndex...)
        }
        
        // Then delete from model context
        for message in messagesToDelete {
            print("🗑️ Deleting message: \(message.id)")
            modelContext.delete(message)
        }
        
        print("🗑️ Deletion complete. Remaining messages: \(chat.messages.count)")
    }
}

#Preview {
    ChatMessageBubble(
        message: ChatMessage(role: "user", content: "Hello, how are you?", createdAt: Date()),
        showError: true,
        messageText: .constant(""),
        showConfirmation: false
    )
} 