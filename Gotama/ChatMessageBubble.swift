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

/// A view that displays a meditation pause timer with start/skip options
private struct PauseBlock: View {
    @Environment(\.colorScheme) private var colorScheme
    let duration: TimeInterval
    let onComplete: () -> Void
    let onReset: (() -> Void)?
    let isFirstPause: Bool
    
    @State private var timeRemaining: TimeInterval
    @State private var timer: Timer?
    @State private var state: TimerState
    @State private var completedDuration: TimeInterval = 0
    
    enum TimerState {
        case ready
        case active
        case completed
    }
    
    init(duration: TimeInterval, state: TimerState = .ready, isFirstPause: Bool = false, onComplete: @escaping () -> Void, onReset: (() -> Void)? = nil) {
        self.duration = duration
        self.onComplete = onComplete
        self.onReset = onReset
        self.isFirstPause = isFirstPause
        self._timeRemaining = State(initialValue: duration)
        self._state = State(initialValue: state)
    }
    
    private var formattedTime: String {
        let minutes = Int(timeRemaining) / 60
        let seconds = Int(timeRemaining) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            switch state {
            case .ready:
                // Start button - only show for first pause
                if isFirstPause {
                    Button {
                        withAnimation(.spring(duration: 0.3)) {
                            state = .active
                            startTimer()
                            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                        }
                    } label: {
                        ZStack {
                            // Outer breathing circle
                            Circle()
                                .stroke(Color.accent.opacity(0.15), lineWidth: 1)
                                .scaleAnimation(isActive: true, targetScale: 1.05, duration: 3.0)
                            
                            // Inner circle with gradient
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.accent.opacity(0.1),
                                            Color.accent.opacity(0.05)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .padding(4)
                            
                            VStack(spacing: 12) {
                                // Pause duration
                                Text(formattedDuration)
                                    .font(.system(.title3, design: .rounded))
                                    .foregroundStyle(.secondary.opacity(0.8))
                                    .padding(.top, 4)
                                
                                // Start meditation text
                                Text("begin meditation")
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundStyle(.secondary.opacity(0.7))
                                
                                // Subtle play indicator
                                Image(systemName: "play.fill")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.accent.opacity(0.8))
                                    .padding(.vertical, 4)
                            }
                        }
                        .frame(width: 140, height: 140)
                        .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .scaleAnimation(isActive: true, targetScale: 1.02, duration: 2.0)
                } else {
                    // Auto-start for subsequent pauses
                    Color.clear
                        .onAppear {
                            withAnimation(.spring(duration: 0.3)) {
                                state = .active
                                startTimer()
                                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                            }
                        }
                }
                
            case .active:
                // Interactive timer circle
                Button {
                    completedDuration = duration - timeRemaining
                    completeTimer()
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                } label: {
                    ZStack {
                        // Outer ring
                        Circle()
                            .stroke(Color.secondary.opacity(0.12), lineWidth: 2)
                            .overlay {
                                // Progress ring
                                Circle()
                                    .trim(from: 0, to: timeRemaining / duration)
                                    .stroke(
                                        Color.accent.opacity(0.9),
                                        style: StrokeStyle(
                                            lineWidth: 2,
                                            lineCap: .round
                                        )
                                    )
                                    .rotationEffect(.degrees(-90))
                            }
                        
                        // Inner circle background
                        Circle()
                            .fill(Color.secondary.opacity(0.05))
                            .padding(4)
                        
                        // Timer content
                        VStack(spacing: 6) {
                            Text(formattedTime)
                                .font(.system(size: 32, weight: .medium, design: .rounded))
                                .monospacedDigit()
                                .contentTransition(.numericText())
                                .foregroundStyle(.primary.opacity(0.9))
                            
                            Text("tap to continue")
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(.secondary.opacity(0.8))
                                .opacity(timeRemaining < duration * 0.95 ? 1 : 0)
                                .animation(.easeInOut(duration: 0.5), value: timeRemaining)
                        }
                    }
                    .frame(width: 120, height: 120)
                    .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .scaleAnimation(isActive: true, targetScale: 1.02, duration: 2.0)
                
            case .completed:
                // Success state with duration and reset option
                HStack(alignment: .center, spacing: 0) {
                    if let onReset {
                        // Combined success indicator and duration
                        Button {
                            withAnimation {
                                timeRemaining = duration
                                state = .ready
                                onReset()
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .medium))
                                
                                Text(formattedDuration)
                                    .font(.system(.caption, design: .rounded))
                                
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.system(size: 12, weight: .light))
                            }
                            .foregroundStyle(.secondary.opacity(0.8))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.secondary.opacity(0.08))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Spacer(minLength: 0)
                }
                .frame(height: 36)  // Even more compact
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(colorScheme == .dark ? Color(white: 0.1) : Color(white: 0.97))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 0.1
            } else {
                completedDuration = duration
                completeTimer()
            }
        }
    }
    
    private func completeTimer() {
        timer?.invalidate()
        timer = nil
        withAnimation(.spring(duration: 0.3)) {
            state = .completed
        }
        // Soft success haptic when timer completes
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        // Small delay to show completion state before continuing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            onComplete()
        }
    }
}

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
                print("⏲️ Processing single-line pause block: \(trimmedLine)")
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
                    print("⏲️ Adding to pause block: \(line)")
                } else {
                    print("📚 Adding to citation block: \(line)")
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
                CitationBlock(content: line.content)
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
        
        if isActive {
            let duration = extractPauseDuration(from: line.content)
            return PauseBlock(duration: duration, isFirstPause: isFirstPause, onComplete: {
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
            })
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
            // Show completed pause block with reset option
            return PauseBlock(duration: extractPauseDuration(from: line.content), state: .completed, isFirstPause: isFirstPause, onComplete: {
                // No-op since it's already completed
            }, onReset: {
                print("⏲️ Resetting from completed pause block at index: \(currentPauseIndex)")
                // Reset to this pause block and hide subsequent text
                withAnimation(.easeInOut) {
                    currentPauseIndex = pauseIndices.firstIndex(of: line.index) ?? currentPauseIndex
                    hasActivePause = false
                }
            })
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
                    .padding(.bottom, 2)
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