import Foundation
import SwiftData

enum AnthropicError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case invalidResponse
    case apiError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from server"
        case .apiError(let message):
            return message
        }
    }
}

actor AnthropicClient {
    private let baseURL = "https://api.anthropic.com/v1"
    private let model = "claude-3-5-sonnet-20241022"
    private var apiKey: String?
    
    init() { }
    
    func configure(with apiKey: String) async {
        print("🔐 AnthropicClient: Configuring with API key of length \(apiKey.count)")
        self.apiKey = apiKey
    }
    
    func sendMessage(_ content: String, previousMessages: [ChatMessage] = []) async throws -> AsyncThrowingStream<String, Error> {
        guard let apiKey = self.apiKey else {
            print("❌ AnthropicClient: API key not configured")
            throw AnthropicError.apiError("API key not configured")
        }
        print("✅ AnthropicClient: Using API key of length \(apiKey.count)")
        
        guard let url = URL(string: "\(baseURL)/messages") else {
            throw AnthropicError.invalidURL
        }
        
        // Convert previous messages to Anthropic format
        let messages = previousMessages.map { [
            "role": $0.role,
            "content": $0.content
        ] }
        
        // Add the new message
        let allMessages = messages + [["role": "user", "content": content]]
        
        let body: [String: Any] = [
            "model": model,
            "messages": allMessages,
            "max_tokens": 1024,
            "stream": true
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            print("Error serializing request body: \(error)")
            throw AnthropicError.apiError("Failed to prepare request")
        }
        
        return AsyncThrowingStream { continuation in
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("Network error: \(error)")
                    continuation.finish(throwing: AnthropicError.networkError(error))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    continuation.finish(throwing: AnthropicError.invalidResponse)
                    return
                }
                
                if let data = data, httpResponse.statusCode != 200 {
                    // Try to parse error response
                    if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let error = errorJson["error"] as? [String: Any],
                       let message = error["message"] as? String {
                        print("API error: \(message)")
                        continuation.finish(throwing: AnthropicError.apiError(message))
                    } else {
                        print("HTTP error: \(httpResponse.statusCode)")
                        continuation.finish(throwing: AnthropicError.apiError("Status code: \(httpResponse.statusCode)"))
                    }
                    return
                }
                
                // Handle SSE response
                if let data = data {
                    let events = String(decoding: data, as: UTF8.self)
                        .components(separatedBy: "\n\n")
                    
                    for event in events {
                        if event.hasPrefix("data:") {
                            let jsonString = event.dropFirst(5).trimmingCharacters(in: .whitespaces)
                            if let data = jsonString.data(using: .utf8),
                               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                                if let type = json["type"] as? String {
                                    switch type {
                                    case "content_block_delta":
                                        if let delta = json["delta"] as? [String: Any],
                                           let text = delta["text"] as? String {
                                            continuation.yield(text)
                                        }
                                    case "message_stop":
                                        continuation.finish()
                                    case "error":
                                        if let error = json["error"] as? [String: Any],
                                           let message = error["message"] as? String {
                                            continuation.finish(throwing: AnthropicError.apiError(message))
                                        }
                                    default:
                                        break
                                    }
                                }
                            }
                        }
                    }
                }
            }
            task.resume()
        }
    }
} 