import SwiftUI

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
struct ChatCitationBlock: View {
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