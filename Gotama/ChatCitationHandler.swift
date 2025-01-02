import Foundation

/// Handles processing of citation blocks in message streams
@MainActor
final class CitationHandler {
    // MARK: - Properties
    
    /// Tracks if we're currently inside a citation block
    private var inCitationBlock = false
    
    /// Accumulates citation text while processing a block
    private var citationBuffer = String()
    
    /// Tracks the number of citation blocks processed
    private var citationCount = 0
    
    // MARK: - Public Methods
    
    /// Process a chunk of text from the stream, handling citation blocks
    /// - Parameter text: The text chunk to process
    /// - Returns: A tuple containing:
    ///   - shouldBuffer: Whether the text should be buffered (true if in citation block)
    ///   - processedText: The processed text if ready to be displayed, nil if buffering
    func handleStreamChunk(_ text: String) -> (shouldBuffer: Bool, processedText: String?) {
        // print("📚 Processing chunk for citations: \(text)")
        
        // Check if we're entering a citation block or already in one
        if text.contains("<citation>") || inCitationBlock {
            return handleCitationChunk(text)
        }
        
        // Regular text, no buffering needed
        return (false, text)
    }
    
    /// Reset the handler state
    func reset() {
        print("📚 Resetting citation handler")
        inCitationBlock = false
        citationBuffer = ""
        citationCount = 0
    }
    
    // MARK: - Private Methods
    
    private func handleCitationChunk(_ text: String) -> (shouldBuffer: Bool, processedText: String?) {
        // Starting a new citation block
        if !inCitationBlock {
            print("📚 Starting new citation block")
            inCitationBlock = true
            citationBuffer = text
            citationCount += 1
            return (true, nil)
        }
        
        // Continue buffering citation content
        print("📚 Buffering citation chunk: \(text)")
        citationBuffer += text
        
        // Check if we've reached the end of the citation block
        if text.contains("</citation>") || 
           (citationBuffer.contains("</citation") && text.contains(">")) {
            print("📚 Completing citation block \(citationCount)")
            inCitationBlock = false
            let finalBuffer = citationBuffer
            citationBuffer = ""
            return (false, finalBuffer)
        }
        
        // Still in citation block, continue buffering
        return (true, nil)
    }
} 