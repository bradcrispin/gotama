import Foundation

/// An async sequence that handles streaming responses from the Anthropic API.
/// Parses SSE (Server-Sent Events) data and yields text chunks.
actor AnthropicStream: AsyncSequence {
    typealias Element = String
    
    private let urlSession: URLSession
    private let request: URLRequest
    private var buffer = ""
    private var isCancelled = false
    private var citationBuffer = ""
    private var inCitationBlock = false
    
    init(request: URLRequest, urlSession: URLSession = .shared) {
        self.request = request
        self.urlSession = urlSession
    }
    
    func cancel() {
        isCancelled = true
    }
    
    nonisolated func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(stream: self)
    }
    
    struct AsyncIterator: AsyncIteratorProtocol {
        let stream: AnthropicStream
        
        func next() async throws -> String? {
            try await stream.next()
        }
    }
    
    private func next() async throws -> String? {
        guard !isCancelled else {
            throw AnthropicError.cancelled
        }
        
        let (bytes, response) = try await urlSession.bytes(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AnthropicError.invalidResponse("Invalid HTTP response")
        }
        
        guard httpResponse.statusCode == 200 else {
            throw AnthropicError.invalidResponse("HTTP \(httpResponse.statusCode)")
        }
        
        for try await line in bytes.lines {
            // Skip empty lines and "data: " prefix
            guard !line.isEmpty, line.hasPrefix("data: ") else { continue }
            
            // Extract the JSON data
            let json = String(line.dropFirst(6))
            
            // Skip empty events
            guard !json.trimmingCharacters(in: .whitespaces).isEmpty else { continue }
            
            do {
                let response = try JSONDecoder().decode(AnthropicTypes.StreamResponse.self, from: Data(json.utf8))
                
                // Handle errors in the stream
                if let error = response.error {
                    throw AnthropicError.streamError(error.message)
                }
                
                // Extract text from delta
                if let text = response.delta?.text {
                    // Check for citation block markers
                    if text.contains("<citation>") {
                        inCitationBlock = true
                        citationBuffer = text
                        continue
                    } else if text.contains("</citation>") {
                        inCitationBlock = false
                        citationBuffer += text
                        return citationBuffer
                    } else if inCitationBlock {
                        citationBuffer += text
                        continue
                    }
                    
                    return text
                }
            } catch {
                print("❌ Stream decode error: \(error)")
                throw AnthropicError.streamError("Failed to decode response: \(error.localizedDescription)")
            }
        }
        
        return nil
    }
} 