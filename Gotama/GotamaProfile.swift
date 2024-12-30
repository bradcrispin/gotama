import Foundation
import SwiftData

/// GotamaProfile represents the global configuration for Gotama's behavior.
/// This is a singleton model - only one instance should exist at any time.
@Model
final class GotamaProfile {
    /// The model to use for chat completions
    var model: String
    
    /// Controls for what information to include in the system prompt
    var includeGoal: Bool
    var includeAboutMe: Bool
    var includeJournal: Bool
    
    /// Selected ancient text for reference
    var selectedText: String
    
    /// Default values for the profile
    static let defaultModel = "claude-3-5-sonnet-20241022"
    
    /// Singleton instance tracking
    private static var instance: GotamaProfile?
    
    /// Private initializer to enforce singleton pattern through getOrCreate
    fileprivate init(model: String) {
        self.model = model
        self.includeGoal = true
        self.includeAboutMe = true
        self.includeJournal = true
        self.selectedText = AncientText.none.rawValue
    }
    
    /// Helper method to ensure single GotamaProfile instance
    /// This method enforces the singleton pattern by:
    /// 1. Returning the existing profile if one exists
    /// 2. Creating a new profile if none exists
    /// 3. Cleaning up any duplicate profiles
    /// - Parameter modelContext: The SwiftData model context
    /// - Returns: The singleton GotamaProfile instance
    /// - Throws: Any errors from SwiftData operations
    @MainActor
    static func getOrCreate(modelContext: ModelContext) throws -> GotamaProfile {
        // First check our cached instance
        if let instance = instance {
            return instance
        }
        
        // If no cached instance, check the database
        let descriptor = FetchDescriptor<GotamaProfile>()
        let existingProfiles = try modelContext.fetch(descriptor)
        
        if let profile = existingProfiles.first {
            // Clean up any extra profiles (shouldn't happen)
            if existingProfiles.count > 1 {
                print("⚠️ Found multiple Gotama profiles, cleaning up...")
                for extraProfile in existingProfiles.dropFirst() {
                    modelContext.delete(extraProfile)
                }
                try modelContext.save()
                print("✅ Cleaned up extra profiles")
            }
            
            // Cache the instance
            instance = profile
            return profile
        }
        
        // Create new profile if none exists
        print("✨ Creating new Gotama profile")
        let newProfile = GotamaProfile(model: defaultModel)
        modelContext.insert(newProfile)
        try modelContext.save()
        
        // Cache the instance
        instance = newProfile
        return newProfile
    }
    
    /// Reset the profile to default values
    /// - Parameter modelContext: The SwiftData model context
    /// - Throws: Any errors from SwiftData operations
    @MainActor
    static func resetToDefault(modelContext: ModelContext) throws {
        let profile = try getOrCreate(modelContext: modelContext)
        profile.model = defaultModel
        try modelContext.save()
        print("🔄 Reset Gotama profile to defaults")
    }
} 