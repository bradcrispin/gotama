import SwiftUI
import SwiftData
import AudioToolbox
import MediaPlayer

/// A view that renders markdown text with support for code blocks and lists
private struct MarkdownText: View {
    let text: String
    var onPauseComplete: (() -> Void)?
    let messageId: PersistentIdentifier
    let scrollProxy: ScrollViewProxy?
    
    @State private var currentPauseIndex: Int = 0
    @State private var hasActivePause: Bool = false
    
    struct Line: Identifiable {
        let id = UUID()
        let content: String
        let type: LineType
        let index: Int
        let indentLevel: Int
        
        enum LineType: Equatable {
            case text
            case emptyLine
            case code
            case citation
            case pause
            case unorderedList
            case orderedList(number: String)
            case styleIndicator
        }
    }
    
    /// Extracts the duration in seconds from a pause block content
    /// Format: <pause>30 seconds</pause> or <pause>10 minutes</pause>
    private func extractPauseDuration(from text: String) -> TimeInterval {
        print("⏲️ Parsing pause duration from text: \(text)")
        
        // Default duration if parsing fails
        let defaultDuration: TimeInterval = 30
        
        // Extract content between tags
        let pattern = "<pause>([\\s\\S]*?)</pause>"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else {
            print("⏲️ Failed to extract pause content, using default duration: \(defaultDuration)")
            return defaultDuration
        }
        
        let innerContent = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        print("⏲️ Extracted pause content: \(innerContent)")
        
        // Split into number and unit
        let components = innerContent.components(separatedBy: .whitespaces)
        guard components.count == 2,
              let number = Double(components[0]) else {
            print("⏲️ Invalid pause format, using default duration: \(defaultDuration)")
            return defaultDuration
        }
        
        let unit = components[1].lowercased()
        let duration: TimeInterval
        
        switch unit {
        case "seconds", "second":
            duration = number
        case "minutes", "minute":
            duration = number * 60
        default:
            print("⏲️ Unknown time unit '\(unit)', using default duration: \(defaultDuration)")
            return defaultDuration
        }
        
        print("⏲️ Parsed pause duration: \(duration) seconds")
        return duration
    }
    
    private var lines: [Line] {
        var result: [Line] = []
        var inCodeBlock = false
        var inCitationBlock = false
        var inPauseBlock = false
        var currentBlock = ""
        
        print("📝 Starting to parse lines")
        let lineArray = text.components(separatedBy: .newlines)
        
        for (index, line) in lineArray.enumerated() {
            let indentLevel = line.prefix(while: { $0 == " " }).count / 2
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            // Handle empty lines
            if trimmedLine.isEmpty {
                if !inCodeBlock && !inCitationBlock && !inPauseBlock {
                    result.append(Line(content: "", type: .emptyLine, index: index, indentLevel: 0))
                } else {
                    // Add empty line to current block if we're in any block type
                    currentBlock += "\n"
                }
                continue
            }
            
            // Check for style indicators at the start of the message
            if index == 0 && trimmedLine.hasPrefix("*") && trimmedLine.hasSuffix("*") {
                result.append(Line(content: trimmedLine, type: .styleIndicator, index: index, indentLevel: 0))
                continue
            }
            
            // Handle citation blocks
            if trimmedLine == "<citation>" {
                print("📚 Starting citation block")
                inCitationBlock = true
                currentBlock = trimmedLine
                continue
            } else if trimmedLine == "</citation>" {
                if inCitationBlock {
                    currentBlock += "\n" + trimmedLine
                    print("📚 Ending citation block: \(currentBlock)")
                    result.append(Line(content: currentBlock, type: .citation, index: index, indentLevel: 0))
                    currentBlock = ""
                    inCitationBlock = false
                }
                continue
            }
            
            // Handle pause blocks - exactly like citation blocks
            if trimmedLine.hasPrefix("<pause>") && trimmedLine.hasSuffix("</pause>") {
                // Single line pause block
                // print("⏲️ Processing single-line pause block: \(trimmedLine)")
                result.append(Line(content: trimmedLine, type: .pause, index: index, indentLevel: 0))
                continue
            } else if trimmedLine == "<pause>" {
                print("⏲️ Starting multi-line pause block")
                inPauseBlock = true
                currentBlock = trimmedLine
                continue
            } else if trimmedLine == "</pause>" {
                if inPauseBlock {
                    currentBlock += "\n" + trimmedLine
                    print("⏲️ Ending multi-line pause block: \(currentBlock)")
                    result.append(Line(content: currentBlock, type: .pause, index: index, indentLevel: 0))
                    currentBlock = ""
                    inPauseBlock = false
                }
                continue
            }
            
            // Add content to current block or handle as regular line
            if inCitationBlock || inPauseBlock {
                if !currentBlock.isEmpty {
                    currentBlock += "\n"
                }
                currentBlock += line
                if inPauseBlock {
                    // print("⏲️ Adding to pause block: \(line)")
                } else {
                    // print("📚 Adding to citation block: \(line)")
                }
                continue
            }
            
            // Handle code blocks
            if trimmedLine.hasPrefix("```") {
                if inCodeBlock {
                    // End code block
                    if !currentBlock.isEmpty {
                        result.append(Line(content: currentBlock, type: .code, index: index, indentLevel: 0))
                        currentBlock = ""
                    }
                    inCodeBlock = false
                } else {
                    // Start code block
                    inCodeBlock = true
                }
                continue
            }
            
            if inCodeBlock {
                if !currentBlock.isEmpty {
                    currentBlock += "\n"
                }
                currentBlock += line
                continue
            }
            
            // Handle regular text
            result.append(Line(content: trimmedLine, type: .text, index: index, indentLevel: indentLevel))
        }
        
        // Add any remaining block
        if !currentBlock.isEmpty {
            let blockType: Line.LineType
            if inCodeBlock {
                blockType = .code
            } else if inCitationBlock {
                blockType = .citation
            } else if inPauseBlock {
                blockType = .pause
            } else {
                blockType = .text
            }
            print("📝 Adding remaining block of type \(blockType): \(currentBlock)")
            result.append(Line(content: currentBlock, type: blockType, index: lineArray.count, indentLevel: 0))
        }
        
        return result
    }
    
    private func formatText(_ text: String) -> Text {
        var result = Text("")
        var currentIndex = text.startIndex
        
        while currentIndex < text.endIndex {
            if let asteriskRange = text[currentIndex...].range(of: "*"),
               let endAsteriskRange = text[asteriskRange.upperBound...].range(of: "*") {
                // Add text before the asterisk
                if asteriskRange.lowerBound > currentIndex {
                    result = result + Text(text[currentIndex..<asteriskRange.lowerBound])
                }
                
                // Add italicized text with secondary color
                let italicText = text[asteriskRange.upperBound..<endAsteriskRange.lowerBound]
                result = result + Text(String(italicText))
                    .italic()
                    .foregroundStyle(.secondary)
                
                // Update current index to after the end asterisk
                currentIndex = endAsteriskRange.upperBound
            } else {
                // Add remaining text
                result = result + Text(text[currentIndex...])
                break
            }
        }
        
        return result
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            let pauseIndices = lines.indices.filter { lines[$0].type == .pause }
            
            ForEach(Array(zip(lines.indices, lines)), id: \.1.id) { index, line in
                if let pauseIndex = pauseIndices.firstIndex(of: index) {
                    // Only show pause blocks up to current one
                    if pauseIndex <= currentPauseIndex {
                        pauseBlockView(for: line, isActive: pauseIndex == currentPauseIndex && !hasActivePause)
                    }
                } else if pauseIndices.isEmpty {
                    // If no pause blocks, show everything
                    renderLine(line, at: index)
                } else {
                    // For text before first pause or between pauses
                    let nextPauseIndex = pauseIndices[currentPauseIndex]
                    if index < nextPauseIndex {
                        // Show text before current pause block
                        renderLine(line, at: index)
                    } else if currentPauseIndex > 0 && index > pauseIndices[currentPauseIndex - 1] && index < nextPauseIndex {
                        // Show text between completed pause and current pause
                        renderLine(line, at: index)
                    } else if hasActivePause && currentPauseIndex == pauseIndices.count - 1 && index > nextPauseIndex {
                        // Show text after last pause only when it's completed
                        renderLine(line, at: index)
                    }
                }
            }
        }
    }
    
    private func renderLine(_ line: Line, at index: Int) -> some View {
        Group {
            switch line.type {
            case .styleIndicator:
                Text(String(line.content.dropFirst().dropLast()))
                    .italic()
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 12)
            case .text:
                formatText(line.content)
                    .padding(.vertical, 4)
                    .transition(.opacity.animation(.easeIn(duration: 0.15)))
            case .emptyLine:
                Spacer()
                    .frame(height: 16)
            case .code:
                Text(line.content)
                    .font(.system(.body, design: .monospaced))
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.vertical, 8)
            case .citation:
                ChatCitationBlock(content: line.content)
            case .pause:
                EmptyView() // Already handled above
            case .unorderedList:
                unorderedListView(for: line, at: index)
                    .transition(.opacity.animation(.easeIn(duration: 0.15)))
            case .orderedList(let number):
                orderedListView(for: line, number: number)
                    .transition(.opacity.animation(.easeIn(duration: 0.15)))
            }
        }
    }
    
    private func pauseBlockView(for line: Line, isActive: Bool) -> some View {
        let pauseIndices = lines.indices.filter { lines[$0].type == .pause }
        let isFirstPause = pauseIndices.first == line.index
        let isLastPause = pauseIndices.last == line.index
        
        print("🎯 Creating PauseBlock - First: \(isFirstPause), Last: \(isLastPause), Active: \(isActive)")
        
        if isActive {
            let duration = extractPauseDuration(from: line.content)
            return ChatPauseBlock(
                duration: duration,
                isFirstPause: isFirstPause,
                isLastPause: isLastPause,
                onComplete: {
                    print("⏲️ Completed pause block at index: \(currentPauseIndex)")
                    hasActivePause = true
                    
                    // Move to next pause block or complete
                    if currentPauseIndex < pauseIndices.count - 1 {
                        // Scroll to message using the same animation as message sending
                        if let proxy = scrollProxy {
                            withAnimation(.spring(duration: 0.3)) {
                                proxy.scrollTo(messageId, anchor: .bottom)
                            }
                        }
                        
                        // Small delay to allow scroll to complete
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            withAnimation(.easeInOut) {
                                currentPauseIndex += 1
                                hasActivePause = false
                            }
                        }
                    } else if isLastPause {
                        // Final pause complete, trigger strong haptic and continue
                        UIImpactFeedbackGenerator(style: .heavy).impactOccurred(intensity: 1.0)
                        
                        // Ensure final scroll
                        if let proxy = scrollProxy {
                            withAnimation(.spring(duration: 0.3)) {
                                proxy.scrollTo(messageId, anchor: .bottom)
                            }
                        }
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onPauseComplete?()
                        }
                    } else {
                        onPauseComplete?()
                    }
                }, onReset: {
                    print("⏲️ Resetting pause block at index: \(currentPauseIndex)")
                    // Reset to current pause block and hide subsequent text
                    hasActivePause = false
                },
                scrollProxy: scrollProxy,
                messageId: messageId
            )
            .padding(.vertical, 24) // Consistent padding above and below
            .transition(.opacity.combined(with: .scale(scale: 0.95)).animation(.easeInOut(duration: 0.5).delay(3.0))) // Increased delay to 3 seconds
            .onAppear {
                // Ensure pause block is fully visible with a small delay to account for rendering
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if let proxy = scrollProxy {
                        withAnimation(.spring(duration: 0.3)) {
                            proxy.scrollTo(messageId, anchor: .bottom)
                        }
                    }
                }
            }
        } else {
            return ChatPauseBlock(
                duration: extractPauseDuration(from: line.content),
                state: .completed,
                isFirstPause: isFirstPause,
                isLastPause: isLastPause,
                onComplete: {
                    // No-op since it's already completed
                }, onReset: {
                    print("⏲️ Resetting from completed pause block at index: \(currentPauseIndex)")
                    // Reset to this pause block and hide subsequent text
                    withAnimation(.easeInOut) {
                        currentPauseIndex = pauseIndices.firstIndex(of: line.index) ?? currentPauseIndex
                        hasActivePause = false
                    }
                },
                scrollProxy: scrollProxy,
                messageId: messageId
            )
            .padding(.vertical, 24) // Consistent padding above and below
        }
    }
    
    private func unorderedListView(for line: Line, at index: Int) -> some View {
        let lastNumberedIndex = (0..<index).reversed().first { i in
            if case .orderedList = lines[i].type {
                return true
            }
            return false
        }
        
        let shouldNest = lastNumberedIndex.map { lastIndex in
            let numberedIndent = lines[lastIndex].indentLevel
            let hasStayedNested = (lastIndex..<index).allSatisfy { i in
                lines[i].indentLevel >= numberedIndent
            }
            return line.indentLevel >= numberedIndent && hasStayedNested
        } ?? false
        
        return HStack(alignment: .top, spacing: 8) {
            Text("-")
                .foregroundStyle(.secondary)
            formatText(line.content)
                .padding(.leading, line.indentLevel > 0 ? CGFloat(line.indentLevel * 16) : 0)
        }
        .padding(.leading, shouldNest ? 16 : 0)
        .padding(.vertical, 4)
    }
    
    private func orderedListView(for line: Line, number: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(number).")
                .foregroundStyle(.secondary)
                .frame(width: 24, alignment: .trailing)
            formatText(line.content)
                .padding(.leading, line.indentLevel > 1 ? CGFloat((line.indentLevel - 1) * 16) : 0)
        }
        .padding(.leading, line.indentLevel > 0 ? 16 : 0)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }
}

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
    @Query private var settings: [Settings]
    
    let message: ChatMessage
    var onRetry: (() async -> Void)?
    let showError: Bool
    @Binding var messageText: String
    let showConfirmation: Bool
    var onPauseComplete: (() -> Void)?
    let scrollProxy: ScrollViewProxy?
    
    @State private var showCopied = false
    @State private var showDeleteConfirmation = false
    @State private var showEditConfirmation = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Show name labels above messages
            if let firstName = settings.first?.firstName,
               !firstName.isEmpty,
               message.role == "user" {
                Text(firstName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 16)
                    .padding(.bottom, 2)
            } else if message.role == "assistant" {
                Text("Gotama")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 16)
                    .padding(.bottom, -8)
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    if message.isThinking == true {
                        ChatThinkingIndicator()
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                    } else {
                        MarkdownText(
                            text: message.content,
                            onPauseComplete: onPauseComplete,
                            messageId: message.persistentModelID,
                            scrollProxy: scrollProxy
                        )
                        .textSelection(.enabled)
                        .padding(.vertical, 8)
                        .padding(.horizontal, message.role == "user" ? 12 : 16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contextMenu(menuItems: {
                            Button {
                                UIPasteboard.general.string = message.content
                            } label: {
                                Label("Copy", systemImage: "doc.on.doc")
                                    .font(.subheadline)
                            }
                            
                            if message.role == "user" {
                                Button {
                                    editMessage()
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                
                                Button<Label<Text, Image>>(role: .destructive) {
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
        // print("✏️ Starting message edit")
        
        // Set the message text for editing
        messageText = message.content
        // print("📝 Loaded message text for editing: \(messageText)")
        
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
        showConfirmation: false,
        scrollProxy: nil
    )
} 