import SwiftUI
import SwiftData

@Observable class OnboardingViewModel {
    private var steps: [OnboardingStep]
    private var currentStepIndex: Int = 0
    private let modelContext: ModelContext
    
    var currentStep: OnboardingStep? {
        guard currentStepIndex < steps.count else { return nil }
        return steps[currentStepIndex]
    }
    
    var isComplete: Bool {
        currentStepIndex >= steps.count
    }
    
    // Animation states
    var showTitle = false
    var showSubtitle = false
    var showInput = false
    var viewOpacity = 0.0
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.steps = [
            .nameStep(modelContext: modelContext)
            // Add more steps here as needed
        ]
    }
    
    func start() {
        guard let step = currentStep else { return }
        
        // Reset states
        showTitle = false
        showSubtitle = false
        showInput = false
        viewOpacity = 0.0
        
        // Fade in view
        withAnimation(.easeIn(duration: 0.3)) {
            viewOpacity = 1.0
        }
        
        // Animate title after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeOut(duration: step.animationDuration)) {
                self.showTitle = true
            }
            
            // Animate subtitle
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.easeOut(duration: step.animationDuration)) {
                    self.showSubtitle = true
                }
                
                // Show input after content is displayed
                DispatchQueue.main.asyncAfter(deadline: .now() + step.delayBeforeInput) {
                    withAnimation(.easeOut(duration: step.animationDuration)) {
                        self.showInput = true
                    }
                }
            }
        }
    }
    
    func processInput(_ input: String) async -> Bool {
        guard let step = currentStep else { return false }
        
        // Validate input
        guard step.validate(input) else { return false }
        
        // Process the input
        let success = await step.process(input, modelContext)
        if success {
            // Fade out current step
            withAnimation(.easeOut(duration: 0.3)) {
                viewOpacity = 0.0
            }
            
            // Move to next step
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.currentStepIndex += 1
                if !self.isComplete {
                    self.start()
                }
            }
        }
        
        return success
    }
} 


struct OnboardingContent {
    let title: String
    let subtitle: String?
    let inputPlaceholder: String
    let inputType: OnboardingInputType
}

enum OnboardingInputType {
    case name
    case text
    case selection([String])  // For future use with multiple choice
    case multiline           // For future use with text areas
}

struct OnboardingStep: Identifiable {
    let id: Int
    let content: OnboardingContent
    let isOptional: Bool
    let validate: (String) -> Bool
    let process: (String, ModelContext) async -> Bool
    let animationDuration: Double
    let delayBeforeInput: Double
    
    // Helper for creating the name collection step
    static func nameStep(modelContext: ModelContext) -> OnboardingStep {
        OnboardingStep(
            id: 1,
            content: OnboardingContent(
                title: "Hi, I am Gotama.",
                subtitle: "I teach mindfulness. What should I call you?",
                inputPlaceholder: "Your first name",
                inputType: .name
            ),
            isOptional: false,
            validate: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty },
            process: { name, context in
                let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                do {
                    // Try to fetch existing settings
                    let descriptor = FetchDescriptor<Settings>()
                    let existingSettings = try context.fetch(descriptor)
                    
                    if let settings = existingSettings.first {
                        // Update existing settings
                        settings.firstName = trimmedName
                    } else {
                        // Create new settings if none exist
                        let newSettings = Settings(firstName: trimmedName)
                        context.insert(newSettings)
                    }
                    
                    // Try to save changes explicitly
                    try context.save()
                    return true
                } catch {
                    print("❌ Error processing name step: \(error)")
                    return false
                }
            },
            animationDuration: 0.8,
            delayBeforeInput: 2.0  // Total time for all welcome messages
        )
    }
    
    // Add more step factory methods here as needed
    // Example:
    // static func goalStep() -> OnboardingStep { ... }
    // static func aboutMeStep() -> OnboardingStep { ... }
} 