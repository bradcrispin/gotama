import Foundation
import SwiftData

@MainActor
struct GotamaPrompt {
    private static let basePrompt = """
    %@
    """
    
    private static let userInfo = """
    - My name is %@.
    """
    
    private static let goalInfo = """
    - My goal: %@
    """

    private static let aboutMeInfo = """
    - About me: %@
    """
    
    private static let journalInfo = """
    
    My journal:
    %@
    """
    
    static func buildPrompt(settings: Settings?, modelContext: ModelContext? = nil) -> String {
        var components: [String] = []
        
        // Get Gotama's profile
        var basePromptText = "You are a hyper intelligent AI assistant named Gotama."
        var profile: GotamaProfile?
        if let context = modelContext {
            do {
                profile = try GotamaProfile.getOrCreate(modelContext: context)
                basePromptText = profile!.systemPrompt
            } catch {
                print("❌ Error getting Gotama profile: \(error)")
            }
        }
        
        // Add base prompt
        components.append(String(format: basePrompt, basePromptText))
        
        // Add user information if available
        if let settings = settings {
            if !settings.firstName.isEmpty {
                components.append(String(format: userInfo, settings.firstName))
            }
            
            if let profile = profile {
                // Only include information if explicitly allowed in profile
                if profile.includeGoal && !settings.goal.isEmpty {
                    components.append(String(format: goalInfo, settings.goal))
                }

                if profile.includeAboutMe && !settings.aboutMe.isEmpty {
                    components.append(String(format: aboutMeInfo, settings.aboutMe))
                }
                
                // Add journal entries if enabled and allowed
                if profile.includeJournal && settings.journalEnabled, let context = modelContext {
                    let descriptor = FetchDescriptor<JournalEntry>(sortBy: [SortDescriptor(\JournalEntry.updatedAt, order: .reverse)])
                    if let entries = try? context.fetch(descriptor) {
                        var journalText = ""
                        var totalLength = 0
                        let maxLength = 1000
                        
                        for entry in entries {
                            let entryText = "- \(entry.text)\n"
                            if totalLength + entryText.count > maxLength {
                                // If adding this entry would exceed limit, stop
                                break
                            }
                            journalText += entryText
                            totalLength += entryText.count
                        }
                        
                        if !journalText.isEmpty {
                            components.append(String(format: journalInfo, journalText))
                        }
                    }
                }
            }
        }
        
        let prompt = components.joined(separator: "\n\n")
        print("🔥 System prompt: \(prompt)")
        
        return prompt
    }
} 
