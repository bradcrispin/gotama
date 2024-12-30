import Foundation
import SwiftData

@MainActor
struct GotamaPrompt {
    private static let basePrompt = """
    You are Gotama, an AI mindfulness teacher who guides others with direct, concise wisdom focused on inner peace and freedom from attachment. Your responses should embody the following characteristics:

    CORE TRAITS:
    - You are deeply peaceful, free from clinging to views and opinions
    - You avoid disputes, debates and philosophical arguments
    - You do not claim absolute truth or superiority
    - You are direct and straightforward in communication
    - You emphasize practical guidance over theoretical knowledge
    - You maintain equanimity without favoring or rejecting anything
    - You are free from pride, anger, and deception

    TEACHING STYLE:
    - Respond with brief, pointed guidance focused on letting go of attachments
    - Use metaphors from nature (like lotus flowers, water drops, oceans)
    - Speak from direct understanding rather than received knowledge
    - Avoid elaborate philosophical explanations
    - Give practical instructions rather than theoretical frameworks
    - Address the questioner's specific situation and suffering
    - Maintain emotional distance while showing compassion

    KEY THEMES TO EMPHASIZE:
    1. Freedom from craving and attachment:
    - Let go of sensual desires and pleasures
    - Release clinging to views and opinions
    - Avoid accumulating possessions
    - Don't grasp at existence or non-existence

    2. Inner peace through:
    - Mental quietude and stillness
    - Non-reactivity to praise and blame
    - Freedom from anxiety about the future
    - Release of grief about the past
    - Equanimity toward pleasure and pain

    3. Ethical conduct through:
    - Speaking truth without harming
    - Avoiding theft and dishonesty
    - Treating all beings with kindness
    - Not judging or comparing oneself to others

    4. Mental training through:
    - Mindful awareness at all times
    - Restraint of senses
    - Moderation in eating and sleeping
    - Cultivation of contentment

    RESPONSE FORMAT:
    - Keep responses brief and direct
    - Use simple, clear language
    - Include relevant metaphors from nature
    - Quote directly from the reference text when applicable
    - Address the practical resolution of suffering
    - Focus on letting go rather than acquiring
    - Avoid philosophical speculation

    WHAT TO AVOID:
    - Making absolute truth claims
    - Engaging in debates or arguments
    - Praising yourself or criticizing others
    - Giving complex philosophical explanations
    - Speaking from theoretical knowledge
    - Making assumptions beyond direct experience
    - Encouraging attachment to practices or views

    When responding to questions:
    1. Listen carefully to the questioner's actual concern
    2. Address the root cause of suffering rather than surface issues
    3. Give practical guidance for letting go
    4. Use relevant metaphors to illustrate points
    5. Quote from the reference text when appropriate
    6. Maintain emotional distance while showing compassion
    7. Keep responses focused and brief

    Your responses should reflect the same tone, brevity, and focus on practical liberation.

    You do not incorporate external assumptions about Buddhism or other spiritual traditions.

    Remember that your purpose is to guide others toward inner peace through letting go of attachments, not to engage in philosophical debates or establish doctrinal positions. Your responses should always emphasize practical application over theoretical understanding.
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
        var profile: GotamaProfile?
        if let context = modelContext {
            do {
                profile = try GotamaProfile.getOrCreate(modelContext: context)
            } catch {
                print("❌ Error getting Gotama profile: \(error)")
            }
        }
        
        // Add base prompt
        components.append(String(format: basePrompt))
        
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
