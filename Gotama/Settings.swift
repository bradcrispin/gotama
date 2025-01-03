import Foundation
import SwiftData

@Model
final class Settings {
    var firstName: String
    var anthropicApiKey: String
    // var priorExperience: String
    var aboutMe: String
    var goal: String
    var journalEnabled: Bool
    var mindfulnessBellEnabled: Bool
    var meditationTimerEnabled: Bool
    
    // Mindfulness Bell Settings
    var mindfulnessBellStartTime: Date?
    var mindfulnessBellEndTime: Date?
    var mindfulnessBellIntervalHours: Double
    var mindfulnessBellIsScheduled: Bool
    
    init(firstName: String = "Brad", anthropicApiKey: String = "", priorExperience: String = "", aboutMe: String = "", goal: String = "", journalEnabled: Bool = true, mindfulnessBellEnabled: Bool = true, meditationTimerEnabled: Bool = true, mindfulnessBellStartTime: Date? = nil, mindfulnessBellEndTime: Date? = nil, mindfulnessBellIntervalHours: Double = 0, mindfulnessBellIsScheduled: Bool = false) {
        
        #if DEBUG
        // Try to load API key from environment in development
        let devApiKey = DevelopmentSettings.loadDevApiKey()
        self.anthropicApiKey = devApiKey.isEmpty ? anthropicApiKey : devApiKey
        #else
        self.anthropicApiKey = anthropicApiKey
        #endif
        
        self.firstName = firstName
        // self.priorExperience = priorExperience
        self.aboutMe = aboutMe
        self.goal = goal
        self.journalEnabled = journalEnabled
        self.mindfulnessBellEnabled = mindfulnessBellEnabled
        self.meditationTimerEnabled = meditationTimerEnabled
        self.mindfulnessBellStartTime = mindfulnessBellStartTime
        self.mindfulnessBellEndTime = mindfulnessBellEndTime
        self.mindfulnessBellIntervalHours = mindfulnessBellIntervalHours
        self.mindfulnessBellIsScheduled = mindfulnessBellIsScheduled
    }
    
    // Helper method to ensure single Settings instance
    static func getOrCreate(modelContext: ModelContext) throws -> Settings {
        let descriptor = FetchDescriptor<Settings>()
        let existingSettings = try modelContext.fetch(descriptor)
        
        if let settings = existingSettings.first {
            // If there are multiple settings objects (shouldn't happen), clean up extras
            if existingSettings.count > 1 {
                print("⚠️ Found multiple settings objects, cleaning up...")
                for extraSettings in existingSettings.dropFirst() {
                    modelContext.delete(extraSettings)
                }
            }
            return settings
        }
        
        // Create new settings if none exist
        let newSettings = Settings()
        modelContext.insert(newSettings)
        try modelContext.save()
        return newSettings
    }
} 