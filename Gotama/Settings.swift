import Foundation
import SwiftData

@Model
final class Settings {
    var firstName: String
    var anthropicApiKey: String
    var aboutMe: String
    var goal: String
    var journalEnabled: Bool
    
    init(firstName: String = "", anthropicApiKey: String = "", aboutMe: String = "", goal: String = "", journalEnabled: Bool = false) {
        self.firstName = firstName
        self.anthropicApiKey = anthropicApiKey
        self.aboutMe = aboutMe
        self.goal = goal
        self.journalEnabled = journalEnabled
    }
} 