import Foundation
import SwiftData

@Model
final class Settings {
    var firstName: String
    var anthropicApiKey: String
    
    init(firstName: String = "", anthropicApiKey: String = "") {
        self.firstName = firstName
        self.anthropicApiKey = anthropicApiKey
    }
} 