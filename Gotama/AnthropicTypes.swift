import Foundation

/// Errors that can occur during API interactions
enum AnthropicError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case invalidResponse(String)
    case apiError(String)
    case streamError(String)
    case cancelled
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse(let message):
            return "Invalid response: \(message)"
        case .apiError(let message):
            return message
        case .streamError(let message):
            return "Stream error: \(message)"
        case .cancelled:
            return "Request cancelled"
        }
    }
}

/// Models for the Anthropic API request and response types
enum AnthropicTypes {
    /// Message role type
    enum Role: String, Codable {
        case user
        case assistant
    }
    
    /// Message structure for API requests
    struct Message: Codable {
        let role: Role
        let content: String
    }
    
    /// Request body for the chat completion endpoint
    struct RequestBody: Codable {
        let model: String
        let messages: [Message]
        let max_tokens: Int
        let stream: Bool
        let temperature: Double
        let system: String?
    }
    
    /// Response structure for non-streaming requests
    struct Response: Codable {
        let content: [ContentBlock]
        let role: String
        let model: String
        let stop_reason: String?
        let type: String
        
        struct ContentBlock: Codable {
            let text: String
            let type: String
        }
    }
    
    /// Delta response for streaming requests
    struct StreamResponse: Codable {
        let type: String
        let delta: Delta?
        let error: ErrorResponse?
        
        struct Delta: Codable {
            let type: String
            let text: String?
        }
        
        struct ErrorResponse: Codable {
            let type: String
            let message: String
        }
    }
} 