import Foundation
import SwiftData

@Model
final class Settings {
    var firstName: String
    var anthropicApiKey: String
    var aboutMe: String
    var goal: String
    
    init(firstName: String = "", anthropicApiKey: String = "", aboutMe: String = "", goal: String = "") {
        self.firstName = firstName
        self.anthropicApiKey = anthropicApiKey
        self.aboutMe = aboutMe
        self.goal = goal
    }
} 