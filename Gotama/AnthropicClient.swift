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
    private var apiKey: String?
    
    init() { }
    
    func configure(with apiKey: String) async {
        // print("🔐 AnthropicClient: Configuring with API key of length \(apiKey.count)")
        self.apiKey = apiKey
    }
    
    func sendMessage(_ content: String, settings: Settings?, previousMessages: [ChatMessage] = []) async throws -> AsyncThrowingStream<String, Error> {
        guard let apiKey = self.apiKey else {
            print("❌ AnthropicClient: API key not configured")
            throw AnthropicError.apiError("API key not configured")
        }
        
        if let settings = settings {
            print("👤 User settings - First Name: '\(settings.firstName)'")
        } else {
            print("⚠️ No user settings provided")
        }
        
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
        
        print("📤 Sending to API - \(allMessages.count) messages:")
        for (i, msg) in allMessages.enumerated() {
            print("  \(i + 1). [\(msg["role"] ?? "unknown")]: \(msg["content"] ?? "")")
        }
        
        // Get model context and profile from the first message's chat if available
        let (model, systemPrompt) = await MainActor.run {
            // Get default model from GotamaProfile
            var model = GotamaProfile.defaultModel
            var systemPrompt = GotamaPrompt.buildPrompt(settings: settings, modelContext: nil)
            
            // Try to get profile from context
            if let context = previousMessages.first?.chat?.modelContext {
                do {
                    let profile = try GotamaProfile.getOrCreate(modelContext: context)
                    model = profile.model
                    systemPrompt = GotamaPrompt.buildPrompt(settings: settings, modelContext: context)
                } catch {
                    print("❌ Error getting Gotama profile: \(error)")
                }
            }
            
            return (model, systemPrompt)
        }
        
        let body: [String: Any] = [
            "model": model,
            "system": systemPrompt,
            "messages": allMessages,
            "max_tokens": 1024,
            "stream": true
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
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
                        guard !event.isEmpty else { continue }
                        
                        let eventComponents = event.components(separatedBy: "\n")
                        var eventData: String?
                        
                        for component in eventComponents {
                            if component.hasPrefix("data:") {
                                eventData = component.dropFirst(5).trimmingCharacters(in: .whitespaces)
                            }
                        }
                        
                        guard let eventData = eventData,
                              let data = eventData.data(using: .utf8),
                              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                              let type = json["type"] as? String else {
                            continue
                        }
                        
                        // print("📥 SSE Event - Type: \(type)")
                        
                        switch type {
                        case "message_start":
                            print("🎬 Message stream started")
                            if let message = json["message"] as? [String: Any] {
                                print("📄 Message ID: \(message["id"] ?? "unknown")")
                            }
                            
                        case "content_block_start":
                            if let contentBlock = json["content_block"] as? [String: Any],
                               let blockType = contentBlock["type"] as? String {
                                print("📝 Content block started - Type: \(blockType)")
                            }
                            
                        case "content_block_delta":
                            if let delta = json["delta"] as? [String: Any] {
                                switch delta["type"] as? String {
                                case "text_delta":
                                    if let text = delta["text"] as? String {
                                        // print("📨 Text delta: \(text)")
                                        continuation.yield(text)
                                    }
                                case "input_json_delta":
                                    if let partialJson = delta["partial_json"] as? String {
                                        print("🔧 Tool input delta: \(partialJson)")
                                    }
                                default:
                                    break
                                }
                            }
                            
                        case "content_block_stop":
                            if let index = json["index"] as? Int {
                                print("✅ Content block stopped at index: \(index)")
                            }
                            
                        case "message_delta":
                            if let delta = json["delta"] as? [String: Any],
                               let stopReason = delta["stop_reason"] as? String {
                                print("🔄 Message delta - Stop reason: \(stopReason)")
                            }
                            
                        case "message_stop":
                            print("🏁 Message stream completed")
                            continuation.finish()
                            
                        case "error":
                            if let error = json["error"] as? [String: Any],
                               let message = error["message"] as? String {
                                print("❌ Stream error: \(message)")
                                continuation.finish(throwing: AnthropicError.apiError(message))
                            }
                            
                        case "ping":
                            print("���� Ping received")
                            
                        default:
                            print("⚠️ Unknown event type: \(type)")
                        }
                    }
                }
            }
            task.resume()
            
            // Store task in continuation for cancellation
            continuation.onTermination = { @Sendable _ in
                print("🛑 Cancelling API request")
                task.cancel()
            }
        }
    }
} 