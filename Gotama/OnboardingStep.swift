import SwiftUI
import SwiftData

struct OnboardingContent {
    let messages: [String]
    let inputPlaceholder: String
    let inputType: OnboardingInputType
}

enum OnboardingInputType {
    case name
    case text
    case selection([String])  // For future use with multiple choice
    case multiline           // For future use with text areas
}

@Observable class OnboardingViewModel {
    private var steps: [OnboardingStep] = []  // Start with empty array
    private var currentStepIndex: Int = 0
    private let modelContext: ModelContext
    private var currentAnimationTask: Task<Void, Never>?
    
    var currentStep: OnboardingStep? {
        guard currentStepIndex < steps.count else { return nil }
        return steps[currentStepIndex]
    }
    
    var isComplete: Bool {
        currentStepIndex >= steps.count
    }
    
    var canGoBack: Bool {
        currentStepIndex > 0
    }
    
    // Animation states
    var showMessages = false
    var showInput = false
    var viewOpacity = 0.0
    var messageAnimationProgress = -1.0
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        
        // Configure steps initially
        Task { @MainActor in
            await configureSteps()
        }
        
        // Listen for goal changes
        NotificationCenter.default.addObserver(forName: Notification.Name("GoalSet"), object: nil, queue: .main) { [weak self] _ in
            print("🔄 Goal changed, reconfiguring steps...")
            Task { @MainActor in
                await self?.configureSteps()
            }
        }
    }
    
    @MainActor
    private func configureSteps() async {
        do {
            print("🔄 Configuring onboarding steps...")
            
            // Store current index to restore position
            let currentIndex = currentStepIndex
            
            // Clear existing steps
            steps.removeAll()
            
            // Add initial steps
            steps.append(.nameStep(modelContext: modelContext))
            steps.append(.goalStep(modelContext: modelContext))
            
            // Get settings and configure conditional steps
            let settings = try Settings.getOrCreate(modelContext: modelContext)
            print("📝 Current settings - Goal: \(settings.goal)")
            
            // Add remaining steps
            steps.append(.experienceStep(modelContext: modelContext))
            steps.append(.aboutMeStep(modelContext: modelContext))
            
            print("✅ Onboarding steps configured. Total steps: \(steps.count)")
            
            // Restore position if possible
            currentStepIndex = min(currentIndex, steps.count - 1)
            
            try modelContext.save()
        } catch {
            print("❌ Error configuring onboarding steps: \(error)")
        }
    }
    
    deinit {
        currentAnimationTask?.cancel()
    }
    
    @MainActor
    func start() {
        guard let step = currentStep else { return }
        print("🎬 Starting step \(step.id)")
        
        // Cancel any existing animation sequence
        currentAnimationTask?.cancel()
        
        print("🎭 Setting initial states")
        messageAnimationProgress = -1.0  // Start with no messages visible
        showInput = false
        showMessages = true  // Ensure messages container is visible from the start
        
        // Create new animation sequence
        currentAnimationTask = Task { @MainActor in
            print("📝 Starting message sequence for step \(step.id)")
            
            // Small delay before starting animations
            try? await Task.sleep(for: .seconds(0.2))
            
            let messageCount = step.content.messages.count
            print("📝 Total messages: \(messageCount)")
            
            // Show first message immediately
            withAnimation(.easeOut(duration: 0.8)) {
                messageAnimationProgress = 0.0
            }
            
            // Show remaining messages sequentially
            for i in 1..<messageCount {
                if Task.isCancelled { return }
                print("💭 Preparing message \(i + 1)")
                
                try? await Task.sleep(for: .seconds(1.0))
                if Task.isCancelled { return }
                
                print("🎭 Animating message \(i + 1)")
                withAnimation(.easeOut(duration: 1.5)) {
                    messageAnimationProgress = Double(i)
                }
                
                try? await Task.sleep(for: .seconds(1.5))
                
                print("✅ Message \(i + 1) complete")
            }
            
            // Show input with slight delay
            if Task.isCancelled { return }
            try? await Task.sleep(for: .seconds(0.5))
            
            print("⌨️ Showing input")
            withAnimation(.easeIn(duration: 0.3)) {
                showInput = true
            }
            
            print("✅ Step \(step.id) animation sequence complete")
        }
    }
    
    @MainActor
    func processInput(_ input: String) async -> Bool {
        guard let step = currentStep else { return false }
        
        print("🔄 Processing input for step \(step.id)")
        
        // Validate input for other steps
        guard step.validate(input) else {
            print("❌ Input validation failed")
            return false
        }
        
        // Process the input
        let success = await step.process(input, modelContext)
        if success {
            print("✅ Step \(step.id) processed successfully")
            
            // Fade out current step with synchronized state changes
            print("🎭 Starting fade out animation")
            withAnimation(.easeOut(duration: 0.3)) {
                viewOpacity = 0.0
                showMessages = false
                showInput = false
                messageAnimationProgress = -1.0
            }
            
            try? await Task.sleep(for: .seconds(0.3))
            print("⏱️ Fade out complete")
            
            // Move to next step
            currentStepIndex += 1
            print("📍 Moved to step \(currentStepIndex)")
            
            // If we have more steps, start the next one
            if !isComplete {
                print("🎬 Starting next step")
                
                // Ensure all states are reset before starting next step
                messageAnimationProgress = -1.0
                showMessages = false
                showInput = false
                
                // Small pause before next step
                try? await Task.sleep(for: .seconds(0.3))
                
                // Start next step with synchronized fade in
                withAnimation(.easeIn(duration: 0.3)) {
                    viewOpacity = 1.0
                    showMessages = true  // Show messages container but keep individual messages hidden
                }
                
                // Small delay before starting the step animation sequence
                try? await Task.sleep(for: .seconds(0.2))
                
                start()
            } else {
                print("✨ Onboarding complete")
            }
        } else {
            print("❌ Step processing failed")
        }
        
        return success
    }
    
    @MainActor
    func goBack() {
        guard canGoBack else { return }
        print("⬅️ Going back from step \(currentStepIndex)")
        
        // Synchronized fade out for current step
        Task { @MainActor in
            print("🎭 Starting fade out animation")
            withAnimation(.easeOut(duration: 0.3)) {
                viewOpacity = 0.0
                showMessages = false
                showInput = false
                messageAnimationProgress = -1.0
            }
            
            try? await Task.sleep(for: .seconds(0.3))
            
            // Move back one step
            currentStepIndex -= 1
            print("📍 Moved to step \(currentStepIndex)")
            
            // Reset states before starting previous step
            messageAnimationProgress = -1.0
            showMessages = false
            showInput = false
            
            try? await Task.sleep(for: .seconds(0.1))
            
            print("🎬 Restarting previous step")
            withAnimation(.easeIn(duration: 0.3)) {
                viewOpacity = 1.0
            }
            
            start()
        }
    }
}

struct OnboardingStep: Identifiable {
    let id: Int
    let content: OnboardingContent
    let isOptional: Bool
    let validate: (String) -> Bool
    let process: @MainActor (String, ModelContext) async -> Bool
    
    // Helper for creating the name collection step
    static func nameStep(modelContext: ModelContext) -> OnboardingStep {
        OnboardingStep(
            id: 1,
            content: OnboardingContent(
                messages: [
                    "Hi. I am Gotama. What is your name?"
                ],
                inputPlaceholder: "Your first name",
                inputType: .name
            ),
            isOptional: false,
            validate: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty },
            process: { @MainActor name, context in
                let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                do {
                    // Use the new helper method to ensure single Settings instance
                    let settings = try Settings.getOrCreate(modelContext: context)
                    settings.firstName = trimmedName
                    try context.save()
                    print("✅ Successfully saved name: \(trimmedName)")
                    return true
                } catch {
                    print("❌ Error processing name step: \(error)")
                    return false
                }
            } 
        )
    }
    
    static func goalStep(modelContext: ModelContext) -> OnboardingStep {
        OnboardingStep(
            id: 2,
            content: OnboardingContent(
                messages: [
                    "Why are you here?",
                ],
                inputPlaceholder: "Your goal",
                inputType: .text
            ),
            isOptional: true,
            validate: { _ in true }, // Always valid since it's optional
            process: { @MainActor goal, context in
                do {
                    print("🎯 Processing goal step...")
                    let settings = try Settings.getOrCreate(modelContext: context)
                    let trimmedGoal = goal.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmedGoal.isEmpty {
                        settings.goal = trimmedGoal
                        try context.save()
                        print("✅ Successfully saved goal: \(trimmedGoal)")
                        
                        // Notify that goal has been set to trigger step reconfiguration
                        NotificationCenter.default.post(name: Notification.Name("GoalSet"), object: nil)
                    }
                    return true
                } catch {
                    print("❌ Error processing goal step: \(error)")
                    return false
                }
            }
        )
    }
    
    static func experienceStep(modelContext: ModelContext) -> OnboardingStep {
        OnboardingStep(
            id: 3,
            content: OnboardingContent(
                messages: [
                    "What is your experience with mindfulness?",
                ],
                inputPlaceholder: "Your prior experience",
                inputType: .text
            ),
            isOptional: true,
            validate: { _ in true },
            process: { @MainActor experience, context in
                do {
                    let settings = try Settings.getOrCreate(modelContext: context)
                    let trimmedExperience = experience.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmedExperience.isEmpty {
                        settings.priorExperience = trimmedExperience
                        try context.save()
                        print("✅ Successfully saved prior experience: \(trimmedExperience)")
                    }
                    return true
                } catch {
                    print("❌ Error processing prior experience step: \(error)")
                    return false
                }
            }
        )
    }
    
    static func aboutMeStep(modelContext: ModelContext) -> OnboardingStep {
        OnboardingStep(
            id: 4,
            content: OnboardingContent(
                messages: [
                    "Is there anything you would like me to know?",
                ],
                inputPlaceholder: "About you",
                inputType: .multiline
            ),
            isOptional: true,
            validate: { _ in true },
            process: { @MainActor aboutMe, context in
                do {
                    let settings = try Settings.getOrCreate(modelContext: context)
                    let trimmedAboutMe = aboutMe.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmedAboutMe.isEmpty {
                        settings.aboutMe = trimmedAboutMe
                        try context.save()
                        print("✅ Successfully saved about me: \(trimmedAboutMe)")
                    }
                    return true
                } catch {
                    print("❌ Error processing about me step: \(error)")
                    return false
                }
            }
        )
    }
}

struct ToolUnlockCelebration: ViewModifier {
    @State private var isAnimating = false
    @State private var showCelebration = false
    
    func body(content: Content) -> some View {
        ZStack {
            content
            
            if showCelebration {
                VStack(spacing: 16) {
                    Image(systemName: "book.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.white)
                        .symbolEffect(.bounce, value: isAnimating)
                    
                    Text("Journal Unlocked!")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                }
                .padding(32)
                .background(.accent)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(radius: 10)
                .scaleEffect(isAnimating ? 1 : 0.5)
                .opacity(isAnimating ? 1 : 0)
                .animation(.spring(duration: 0.5), value: isAnimating)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("JournalToolUnlocked"))) { _ in
            showCelebration = true
            withAnimation {
                isAnimating = true
            }
            
            // Hide celebration after delay
            Task {
                try? await Task.sleep(for: .seconds(2))
                await MainActor.run {
                    withAnimation {
                        isAnimating = false
                    }
                }
                try? await Task.sleep(for: .seconds(0.5))
                await MainActor.run {
                    showCelebration = false
                }
            }
        }
    }
}

extension View {
    func toolUnlockCelebration() -> some View {
        modifier(ToolUnlockCelebration())
    }
} 