import SwiftUI
import SwiftData

/// A view that displays a citation block with a copy button
/// 
/// Citation format:
/// ```
/// <citation>
/// <verse>Verse reference</verse>
/// <pali>Pali text</pali>
/// <translation>English translation</translation>
/// </citation>
/// ```
private struct CitationBlock: View {
    @Environment(\.colorScheme) private var colorScheme
    let content: String
    @State private var showCopied = false
    @State private var showPali = false
    @State private var copyTimer: Task<Void, Never>?
    
    private struct CitationContent {
        let verse: String?
        let pali: String?
        let translation: String?
        
        /// Formats text by adding line breaks before capital letters
        private static func formatWithLineBreaks(_ text: String) -> String {
            // Add a line break before any capital letter (except the first character)
            let pattern = "(?<!^)(?=[A-ZĀĪŪṀṄṆṆṚṜḌḤḲḶṂṄṆṚṜṢṬ])"
            return text.replacingOccurrences(
                of: pattern,
                with: "\n\n",
                options: [.regularExpression]
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        init(from text: String) {
            print("📚 Parsing citation from text: \(text)")
            
            // Simple patterns to match each tag
            let versePattern = "<verse>([\\s\\S]*?)</verse>"
            let paliPattern = "<pali>([\\s\\S]*?)</pali>"
            let translationPattern = "<translation>([\\s\\S]*?)</translation>"
            
            // Initialize variables
            var parsedVerse: String? = nil
            var parsedPali: String? = nil
            var parsedTranslation: String? = nil
            
            do {
                // Extract verse
                if let verseMatch = try NSRegularExpression(pattern: versePattern, options: [])
                    .firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)),
                   let verseRange = Range(verseMatch.range(at: 1), in: text) {
                    parsedVerse = String(text[verseRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                }
                
                // Extract pali
                if let paliMatch = try NSRegularExpression(pattern: paliPattern, options: [])
                    .firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)),
                   let paliRange = Range(paliMatch.range(at: 1), in: text) {
                    let rawPali = String(text[paliRange])
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .replacingOccurrences(of: "\n", with: " ")
                        .components(separatedBy: .whitespacesAndNewlines)
                        .filter { !$0.isEmpty }
                        .joined(separator: " ")
                    parsedPali = Self.formatWithLineBreaks(rawPali)
                    print("📚 Parsed pali: \(parsedPali ?? "nil")")
                }
                
                // Extract translation
                if let translationMatch = try NSRegularExpression(pattern: translationPattern, options: [])
                    .firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)),
                   let translationRange = Range(translationMatch.range(at: 1), in: text) {
                    let rawTranslation = String(text[translationRange])
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .replacingOccurrences(of: "\n", with: " ")
                        .components(separatedBy: .whitespacesAndNewlines)
                        .filter { !$0.isEmpty }
                        .joined(separator: " ")
                    parsedTranslation = Self.formatWithLineBreaks(rawTranslation)
                }
            } catch {
                print("❌ Citation parsing error: \(error)")
            }
            
            // Assign final values
            verse = parsedVerse
            pali = parsedPali
            translation = parsedTranslation
        }
        
        var isValid: Bool {
            verse != nil && (pali != nil || translation != nil)
        }
    }
    
    private var citationContent: CitationContent {
        CitationContent(from: content)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                // Header with verse reference and buttons
                if let verse = citationContent.verse {
                    HStack {
                        HStack(spacing: 8) {
                            Text(verse)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            
                            Text("Atthakavagga")
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(colorScheme == .dark ? Color(white: 0.2) : Color(white: 0.9))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        // Only show magnifying glass if Pali text exists
                        if citationContent.pali != nil {
                            Button {
                                withAnimation(.spring(duration: 0.3)) {
                                    showPali.toggle()
                                }
                            } label: {
                                Image(systemName: showPali ? "text.magnifyingglass" : "magnifyingglass")
                                    .foregroundStyle(showPali ? .accent : .secondary)
                            }
                            .buttonStyle(.plain)
                            .padding(.trailing, 8)
                            .accessibilityLabel(showPali ? "Hide Pali text" : "Show Pali text")
                        }
                        
                        Button {
                            // Cancel any existing timer
                            copyTimer?.cancel()
                            copyTimer = nil
                            
                            // Copy formatted text
                            let textToCopy = [
                                citationContent.verse.map { "[\($0)]" },
                                showPali ? citationContent.pali : nil,
                                citationContent.translation
                            ]
                                .compactMap { $0 }
                                .joined(separator: "\n\n")
                            
                            UIPasteboard.general.string = textToCopy
                            withAnimation {
                                showCopied = true
                            }
                            
                            // Start new timer
                            copyTimer = Task { @MainActor in
                                try? await Task.sleep(for: .seconds(2))
                                guard !Task.isCancelled else { return }
                                withAnimation {
                                    showCopied = false
                                }
                                copyTimer = nil
                            }
                        } label: {
                            Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                                .foregroundStyle(showCopied ? .green : .secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(showCopied ? "Copied" : "Copy citation")
                    }
                }
                
                // Citation content
                VStack(alignment: .leading, spacing: 16) {
                    if showPali, let pali = citationContent.pali {
                        Text(pali)
                            .font(.subheadline)
                            .italic()
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .padding(.bottom, 8)
                        
                        // Subtle separator
                        Rectangle()
                            .fill(Color.secondary.opacity(0.2))
                            .frame(height: 0.5)
                            .padding(.bottom, 8)
                    }
                    
                    if let translation = citationContent.translation {
                        Text(translation)
                            .font(.subheadline)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.top, 8)
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(colorScheme == .dark ? Color(white: 0.1) : Color(white: 0.97))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(.vertical, 8)
        .onDisappear {
            copyTimer?.cancel()
            copyTimer = nil
        }
    }
}

/// A view that renders markdown text with support for code blocks and lists
private struct MarkdownText: View {
    let text: String
    
    private struct Line: Identifiable {
        let id = UUID()
        let content: String
        let type: LineType
        let index: Int
        let indentLevel: Int
        
        enum LineType {
            case text
            case emptyLine
            case code
            case citation
            case unorderedList
            case orderedList(number: String)
            case styleIndicator
        }
    }
    
    private var lines: [Line] {
        var result: [Line] = []
        var inCodeBlock = false
        var inCitationBlock = false
        var currentBlock = ""
        
        let lineArray = text.components(separatedBy: .newlines)
        
        for (index, line) in lineArray.enumerated() {
            let indentLevel = line.prefix(while: { $0 == " " }).count / 2
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            // Handle empty lines
            if trimmedLine.isEmpty {
                if !inCodeBlock && !inCitationBlock {
                    result.append(Line(content: "", type: .emptyLine, index: index, indentLevel: 0))
                } else if inCitationBlock {
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
                inCitationBlock = true
                currentBlock = trimmedLine
                continue
            } else if trimmedLine == "</citation>" {
                if inCitationBlock {
                    currentBlock += "\n" + trimmedLine
                    result.append(Line(content: currentBlock, type: .citation, index: index, indentLevel: 0))
                    currentBlock = ""
                    inCitationBlock = false
                }
                continue
            }
            
            if inCitationBlock {
                currentBlock += "\n" + line
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
            
            // Handle lists and regular text
            if let _ = ["- ", "* ", "• "].first(where: { trimmedLine.hasPrefix($0) }) {
                result.append(Line(
                    content: String(trimmedLine.dropFirst(2)),
                    type: .unorderedList,
                    index: index,
                    indentLevel: indentLevel
                ))
            } else if let firstWord = trimmedLine.components(separatedBy: .whitespaces).first,
                      firstWord.hasSuffix("."),
                      firstWord.dropLast().allSatisfy({ $0.isNumber }) {
                let number = String(firstWord.dropLast())
                result.append(Line(
                    content: String(trimmedLine.dropFirst(firstWord.count + 1)),
                    type: .orderedList(number: number),
                    index: index,
                    indentLevel: indentLevel
                ))
            } else {
                result.append(Line(content: trimmedLine, type: .text, index: index, indentLevel: indentLevel))
            }
        }
        
        // Add any remaining code block
        if !currentBlock.isEmpty {
            result.append(Line(content: currentBlock, type: inCodeBlock ? .code : .citation, index: lineArray.count, indentLevel: 0))
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
            ForEach(Array(zip(lines.indices, lines)), id: \.1.id) { index, line in
                switch line.type {
                case .styleIndicator:
                    Text(String(line.content.dropFirst().dropLast()))
                        .italic()
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 12)
                case .text:
                    formatText(line.content)
                        .padding(.vertical, 4)
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
                    CitationBlock(content: line.content)
                case .unorderedList:
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
                    
                    HStack(alignment: .top, spacing: 8) {
                        Text("-")
                            .foregroundStyle(.secondary)
                        formatText(line.content)
                            .padding(.leading, line.indentLevel > 0 ? CGFloat(line.indentLevel * 16) : 0)
                    }
                    .padding(.leading, shouldNest ? 16 : 0)
                    .padding(.vertical, 4)
                case .orderedList(let number):
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
        }
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
                    .padding(.bottom, 2)
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    if message.isThinking == true {
                        ChatThinkingIndicator()
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                    } else {
                        MarkdownText(text: message.content)
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
        showConfirmation: false
    )
} 