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
    
    // MARK: - Development Helpers
    
    /// Determines if the app is running in development mode
    private static var isDevelopment: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
    
    /// Loads the Anthropic API key from environment variables in development mode
    private static func loadDevApiKey() -> String {
        guard isDevelopment else { return "" }
        return ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] ?? ""
    }
    
    init(firstName: String = "", anthropicApiKey: String = "", priorExperience: String = "", aboutMe: String = "", goal: String = "", journalEnabled: Bool = true, mindfulnessBellEnabled: Bool = true, meditationTimerEnabled: Bool = true, mindfulnessBellStartTime: Date? = nil, mindfulnessBellEndTime: Date? = nil, mindfulnessBellIntervalHours: Double = 0, mindfulnessBellIsScheduled: Bool = false) {
        // In development, try to load API key from environment
        let finalApiKey = Settings.isDevelopment ? Settings.loadDevApiKey() : anthropicApiKey
        
        self.firstName = firstName
        self.anthropicApiKey = finalApiKey
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
        
        if Settings.isDevelopment {
            print("🔐 Development mode: API key \(finalApiKey.isEmpty ? "not found" : "loaded") from environment")
        }
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