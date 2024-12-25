struct GotamaPrompt {
    private static let basePrompt = """
    - You are a helpful AI assistant named Gotama.
    - You think carefully before responding.
    - You respond with post gradute quality answers.
    """
    
    private static let userInfo = """
    - My name is %@.
    """
    
    private static let aboutMeInfo = """
    - About me: %@
    """
    
    private static let goalInfo = """
    - My goal: %@
    """
    
    static func buildPrompt(settings: Settings?) -> String {
        var components: [String] = []
        
        // Add base prompt
        components.append(basePrompt)
        
        // Add user information if available
        if let settings = settings {
            if !settings.firstName.isEmpty {
                components.append(String(format: userInfo, settings.firstName))
            }
            
            if !settings.aboutMe.isEmpty {
                components.append(String(format: aboutMeInfo, settings.aboutMe))
            }
            
            if !settings.goal.isEmpty {
                components.append(String(format: goalInfo, settings.goal))
            }
        }
        
        let prompt = components.joined(separator: "\n\n")
        print("🔥 System prompt: \(prompt)")
        
        return prompt
    }
} 
