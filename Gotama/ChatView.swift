import SwiftUI
import SwiftData
import Speech

struct ChatView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var chat: Chat?
    @State private var messageText: String = ""
    @State private var isLoading = false
    @FocusState private var isFocused: Bool
    @State private var isTextFromRecognition = false
    @State private var errorMessage: String?
    @Query private var settings: [Settings]
    @State private var showSettings = false
    @State private var showGotamaProfile = false
    @State private var canCreateNewChat = false
    @Namespace private var animation
    @State private var asteriskRotation = 45.0
    @State private var isAsteriskAnimating = false
    @State private var isAsteriskStopping = false
    @State private var asteriskAnimationSpeed = 8.0
    @State private var asteriskAnimationState = 0
    @State private var scrollProxy: ScrollViewProxy?
    @State private var isNearBottom = true
    @State private var showScrollToBottom = false
    @State private var hasUserScrolled = false
    @State private var pendingMessageText: String?
    @State private var viewOpacity: Double = 0.0
    @State private var hasAppliedInitialAnimation = false
    @State private var isFirstLaunch = true
    @State private var onboardingViewModel: OnboardingViewModel?
    @State private var currentTask: Task<Void, Never>?
    
    @StateObject private var dictationHandler = ChatDictationHandler()
    
    private let haptics = UIImpactFeedbackGenerator(style: .medium)
    private let softHaptics = UIImpactFeedbackGenerator(style: .soft)
    private let anthropic = AnthropicClient()
    
    private func updateCanCreateNewChat() {
        if let currentChat = chat {
            canCreateNewChat = currentChat.messages.contains(where: { $0.role == "assistant" && ($0.isThinking ?? false) == false })
        } else {
            canCreateNewChat = false
        }
    }
    
    private var isApiKeyConfigured: Bool {
        guard let settings = settings.first else {
            print("⚠️ No settings found")
            return false
        }
        // print("🔑 API Key configured: \(!settings.anthropicApiKey.isEmpty)")
        // print("🔑 API Key length: \(settings.anthropicApiKey.count)")
        return !settings.anthropicApiKey.isEmpty
    }
    
    init(chat: Chat?) {
        _chat = State(initialValue: chat)
    }
    
    private func sendMessage() {
        let trimmedText = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        
        haptics.impactOccurred()
        
        // Store the message text before clearing
        pendingMessageText = trimmedText
        
        
        // Clear the text input immediately
        messageText = ""
        
        // Dismiss keyboard
        isFocused = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                     to: nil,
                                     from: nil,
                                     for: nil)
        
        // Handle onboarding
        if let viewModel = onboardingViewModel {
            Task {
                let success = await viewModel.processInput(trimmedText)
                if success && viewModel.isComplete {
                    await MainActor.run {
                        // Transition to normal chat
                        onboardingViewModel = nil
                        startNewChat()
                    }
                }
            }
            return
        }
        
        print("🔍 Checking API key configuration...")
        guard isApiKeyConfigured else {
            print("❌ API key not configured")
            errorMessage = "Tap here to add your Anthropic API key"
            return
        }
        print("✅ API key configured, proceeding with message")
        
        if chat == nil {
            let newChat = Chat()
            let title = trimmedText.trimmingCharacters(in: .whitespacesAndNewlines)
            newChat.title = title.isEmpty ? "New chat" : title
            modelContext.insert(newChat)
            chat = newChat
        }
        
        canCreateNewChat = false
        
        // Get previous messages before adding the new one
        let previousMessages = chat?.messages ?? []
        
        let userMessage = ChatMessage(role: "user", content: trimmedText, createdAt: Date())
        chat?.messages.append(userMessage)
        userMessage.chat = chat
        chat?.updatedAt = Date()
        
        let assistantMessage = ChatMessage(role: "assistant", content: "", createdAt: Date(), isThinking: true)
        chat?.messages.append(assistantMessage)
        assistantMessage.chat = chat
        
        isLoading = true
        
        hasUserScrolled = false // Reset scroll state for new message
        
        currentTask = Task {
            // Configure API key before sending message
            if let settings = settings.first {
                await anthropic.configure(with: settings.anthropicApiKey)
            }
            
            do {
                var chunkCount = 0
                print("📤 Starting message stream...")
                
                print("📨 Sending message with \(previousMessages.count) previous messages:")
                for (index, msg) in previousMessages.enumerated() {
                    print("  \(index + 1). [\(msg.role)]: \(msg.content)")
                }
                print("📨 New message: \(trimmedText)")
                
                let stream = try await anthropic.sendMessage(trimmedText, settings: settings.first, previousMessages: previousMessages)
                
                let startTime = Date()
                for try await text in stream {
                    chunkCount += 1
                    if chunkCount == 1 {
                        let initialDelay = Date().timeIntervalSince(startTime)
                        print("⏱️ First chunk received after \(String(format: "%.2f", initialDelay))s")
                        await MainActor.run {
                            assistantMessage.isThinking = false
                            assistantMessage.content = ""
                            softHaptics.impactOccurred()
                            
                            // Initial scroll to show user message at top
                            if let proxy = scrollProxy {
                                withAnimation(.spring(duration: 0.3)) {
                                    proxy.scrollTo(userMessage.id, anchor: .top)
                                }
                            }
                        }
                    }
                    
                    try await Task.sleep(nanoseconds: 20_000_000) // 20ms delay
                    
                    await MainActor.run {
                        // let beforeLength = assistantMessage.content.count
                        assistantMessage.content += text
                        
                        // Provide subtle haptic feedback every few chunks
                        if chunkCount % 5 == 0 {
                            softHaptics.impactOccurred(intensity: 0.4)
                        }
                        
                        // Continuously update scroll position as content grows
                        if let proxy = scrollProxy, !hasUserScrolled {
                            withAnimation(.spring(duration: 0.3)) {
                                proxy.scrollTo(userMessage.id, anchor: .top)
                            }
                        }
                        
                        // print("📝 Updated content length: \(beforeLength) -> \(assistantMessage.content.count)")
                    }
                }
                
                let totalTime = Date().timeIntervalSince(startTime)
                print("✅ Stream completed: \(chunkCount) chunks in \(String(format: "%.2f", totalTime))s")
                print("📊 Average: \(String(format: "%.2f", Double(chunkCount)/totalTime)) chunks/second")
                
                await MainActor.run {
                    isLoading = false
                    updateCanCreateNewChat()
                    softHaptics.impactOccurred(intensity: 0.7)
                }
            } catch {
                print("❌ Stream error: \(error)")
                await MainActor.run {
                    assistantMessage.isThinking = false
                    handleError(error, for: assistantMessage)
                }
            }
            
            await MainActor.run {
                currentTask = nil
            }
        }
    }
    
    private func stopGeneration() {
        // Use success haptic for a satisfying feel
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        // Cancel the current task
        currentTask?.cancel()
        currentTask = nil
        
        // Remove the last two messages without animation
        if let existingChat = chat {
            let messages = existingChat.messages
            if messages.count >= 2,
               messages[messages.count - 1].role == "assistant",
               messages[messages.count - 2].role == "user" {
                withAnimation(nil) { // Disable animation
                    existingChat.messages.removeLast(2)
                }
            }
        }
        
        // Restore the message text
        if let pendingText = pendingMessageText {
            messageText = pendingText
            pendingMessageText = nil
        }
        
        isLoading = false
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if let error = errorMessage {
                ChatErrorBanner(message: error) {
                    if error.contains("API key") {
                        showSettings = true
                    } else if error.contains("microphone") || error.contains("speech recognition") {
                        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(settingsUrl)
                        }
                    }
                }
            }
            
            if let existingChat = chat, !existingChat.messages.isEmpty {
                ChatScrollView(
                    messages: existingChat.messages,
                    hasUserScrolled: $hasUserScrolled,
                    isNearBottom: $isNearBottom,
                    showScrollToBottom: $showScrollToBottom,
                    messageText: $messageText,
                    viewOpacity: $viewOpacity,
                    onRetry: retryMessage,
                    onScrollProxySet: { proxy in
                        scrollProxy = proxy
                    }
                )
                .safeAreaInset(edge: .bottom) {
                    inputArea
                }
                .transition(.opacity.animation(.easeInOut(duration: 0.3)))
            } else {
                ChatEmptyState(
                    firstName: settings.first?.firstName,
                    asteriskRotation: $asteriskRotation,
                    onboardingViewModel: onboardingViewModel,
                    isAnimating: $isAsteriskAnimating
                )
                .onTapGesture {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                                 to: nil,
                                                 from: nil,
                                                 for: nil)
                }
                .safeAreaInset(edge: .bottom) {
                    inputArea
                }
            }
        }
        .opacity(viewOpacity)
        .animation(.spring(duration: 0.4), value: chat?.messages.isEmpty)
        .animation(.spring(duration: 0.4), value: chat?.id)
        .toolUnlockCelebration()
        .navigationTitle("Gotama")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Button {
                    showGotamaProfile = true
                } label: {
                    HStack(spacing: 3) {
                        Text("Gotama")
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10.5))
                            .imageScale(.small)
                            .offset(y: 1)
                            .opacity(0.75)
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                    }
                }
            }
            
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    if let viewModel = onboardingViewModel, viewModel.canGoBack {
                        viewModel.goBack()
                    } else {
                        dismiss()
                    }
                } label: {
                    Text("")
                }
                .tint(.accent)
            }
            
            if let viewModel = onboardingViewModel, 
               let currentStep = viewModel.currentStep,
               currentStep.isOptional {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task {
                            await viewModel.processInput("")
                        }
                    } label: {
                        Text("Skip")
                            .foregroundStyle(.secondary)
                    }
                }
            } else if onboardingViewModel == nil {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        haptics.impactOccurred()
                        print("🔄 Starting new chat from existing chat")
                        
                        // Clean up current chat if empty
                        if let currentChat = chat, currentChat.messages.isEmpty {
                            modelContext.delete(currentChat)
                        }
                        
                        // Reset asterisk animation
                        asteriskRotation = 45.0
                        isAsteriskAnimating = false
                        
                        // Ensure keyboard focus and visibility with proper timing
                        withAnimation(.spring(duration: 0.4)) {
                            // Create new chat
                            chat = nil
                            messageText = ""
                            errorMessage = nil
                            canCreateNewChat = false
                            print("📱 Chat state reset")
                        }
                        
                        // Start asterisk animation after transition
                        Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(400))
                            startAsteriskAnimation()
                        }
                    } label: {
                        Image(systemName: "plus.message")
                    }
                    .disabled(!canCreateNewChat)
                    .tint(.accent)
                }
            }
        }
        .sheet(isPresented: $showGotamaProfile) {
            GotamaProfileView()
        }
        .onAppear {
            // print("📱 ChatView.body onAppear")
            // print("📊 Initial state - viewOpacity: \(viewOpacity), hasAppliedInitialAnimation: \(hasAppliedInitialAnimation)")
            
            // Check if we need to start onboarding
            Task {
                do {
                    let settings = try Settings.getOrCreate(modelContext: modelContext)
                    if settings.firstName.isEmpty {
                        // If there's an existing onboarding, clean it up
                        if onboardingViewModel != nil {
                            onboardingViewModel = nil
                        }
                        
                        // Create fresh onboarding view model
                        onboardingViewModel = OnboardingViewModel(modelContext: modelContext)
                        
                        // For first launch, start immediately with full opacity
                        if isFirstLaunch {
                            print("🚀 First launch - starting onboarding immediately")
                            viewOpacity = 1.0  // Set full opacity immediately
                            onboardingViewModel?.viewOpacity = 1.0
                            onboardingViewModel?.showMessages = true  // Ensure messages container is visible
                            onboardingViewModel?.start()
                        } else {
                            print("🚀 Not first launch")
                            // Just show the content without animation
                            onboardingViewModel?.viewOpacity = 1.0
                            onboardingViewModel?.showMessages = true
                            onboardingViewModel?.showInput = true
                            onboardingViewModel?.messageAnimationProgress = Double(onboardingViewModel?.currentStep?.content.messages.count ?? 0) - 1
                        }
                    }
                } catch {
                    print("❌ Error checking settings: \(error)")
                }
            }

            if let chatId = chat?.id {
                print("📱 ChatView appeared for chat: \(chatId)")
                updateCanCreateNewChat()
                
                // Existing chat animation
                withAnimation(.easeInOut(duration: 0.8)) {
                    viewOpacity = 1.0
                }
            } else if !isFirstLaunch || onboardingViewModel == nil {  // Handle both non-first launch and regular chat creation
                // Reset opacity if we haven't animated yet
                if !hasAppliedInitialAnimation {
                    viewOpacity = 0.0
                }
                
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(0.1))  // Minimal delay for non-first launch
                    withAnimation(.easeInOut(duration: 1.7)) {
                        viewOpacity = 1.0
                        hasAppliedInitialAnimation = true
                    }
                    
                    if let viewModel = onboardingViewModel {
                        startAsteriskAnimation()
                        viewModel.start()
                    } else {
                        startAsteriskAnimation()
                    }
                }
            }
            
            // Configure Anthropic client
            Task {
                do {
                    let settings = try Settings.getOrCreate(modelContext: modelContext)
                    await anthropic.configure(with: settings.anthropicApiKey)
                } catch {
                    print("❌ Error configuring Anthropic client: \(error)")
                }
            }
        }
        .onDisappear {
            print("📱 ChatView.body onDisappear")
            if let chat = chat, chat.messages.isEmpty {
                modelContext.delete(chat)
            }
        }
        // IF user clicks error message for API key, show settings
        .sheet(isPresented: $showSettings) {
            SettingsView(focusApiKey: true) {
                // Clear error if API key is now configured
                if isApiKeyConfigured {
                    errorMessage = nil
                }
            }
        }
        .onChange(of: isFocused) { wasFocused, isNowFocused in
            print("🎯 Focus state changed: \(wasFocused) -> \(isNowFocused)")
            print("📱 Current view state - viewOpacity: \(viewOpacity), hasAppliedInitialAnimation: \(hasAppliedInitialAnimation)")
        }
        .onChange(of: dictationHandler.errorMessage) { _, newError in
            if let error = newError {
                errorMessage = error
            }
        }
    }
    
    
    // Chat input area
    @ViewBuilder
    private var inputArea: some View {
        ChatInputArea(
            messageText: $messageText,
            isLoading: $isLoading,
            isRecording: .init(
                get: { dictationHandler.isRecording },
                set: { _ in }
            ),
            errorMessage: $errorMessage,
            viewOpacity: $viewOpacity,
            inputPlaceholder: onboardingViewModel?.currentStep?.content.inputPlaceholder ?? "Chat with Gotama",
            showInput: onboardingViewModel?.showInput ?? true,
            onSendMessage: sendMessage,
            onStopGeneration: stopGeneration,
            onStartDictation: startDictation,
            onStopDictation: stopDictation
        )
    }
    
    private func handleError(_ error: Error, for message: ChatMessage) {
        message.content = "I am sorry but I am getting an error and can't respond right now."
        message.isThinking = false
        isLoading = false
        if let anthropicError = error as? AnthropicError {
            errorMessage = anthropicError.localizedDescription
        } else {
            errorMessage = "Failed to send message: \(error.localizedDescription)"
        }
    }
    
    private func retryMessage(_ message: ChatMessage) async {
        guard message.role == "assistant",
              let userMessage = chat?.messages.prefix(while: { $0 !== message }).last,
              userMessage.role == "user" else { return }
        
        await MainActor.run {
            message.error = nil
            message.content = ""
            isLoading = true
        }
        
        do {
            var responseText = ""
            print("🔄 Retrying message stream...")
            let previousMessages = Array(chat?.messages.prefix(while: { $0 !== message }) ?? [])
            print("📨 Retrying with \(previousMessages.count) previous messages:")
            for (index, msg) in previousMessages.enumerated() {
                print("  \(index + 1). [\(msg.role)]: \(msg.content)")
            }
            
            let stream = try await anthropic.sendMessage(userMessage.content, settings: settings.first, previousMessages: previousMessages)
            
            for try await text in stream {
                print("📥 Retry chunk: \(text)")
                await MainActor.run {
                    responseText += text
                    message.content = responseText
                }
            }
            
            print("✅ Retry stream completed successfully")
            await MainActor.run {
                isLoading = false
            }
        } catch {
            print("❌ Retry stream error: \(error)")
            await MainActor.run {
                handleError(error, for: message)
            }
        }
    }
    
    private func startAsteriskAnimation() {
        guard !isAsteriskAnimating else { return }
        isAsteriskAnimating = true
        isAsteriskStopping = false
        
        // Reset rotation to starting position + one full rotation
        asteriskRotation = 45
        withAnimation(.easeInOut(duration: 8.0)
            .repeatForever(autoreverses: false)) {
            asteriskRotation = 405 // 45 + 360 degrees
        }
    }
    
    private func startDictation() {
        dictationHandler.startDictation { text in
            isTextFromRecognition = true
            messageText = text
            // Reset flag after a small delay
            Task { @MainActor in
                try? await Task.sleep(for: .nanoseconds(100_000_000))
                isTextFromRecognition = false
            }
        }
    }
    
    private func stopDictation() {
        dictationHandler.stopDictation()
        softHaptics.impactOccurred()
    }
    
    private func startNewChat() {
        // Reset asterisk animation
        asteriskRotation = 45.0
        isAsteriskAnimating = false
        
        withAnimation(.spring(duration: 0.4)) {
            chat = nil
            messageText = ""
            errorMessage = nil
            canCreateNewChat = false
        }
        
        // Start asterisk animation after transition
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            startAsteriskAnimation()
        }
    }

    @MainActor
    private func handleOnboardingCompletion() async {
        print("🎉 Handling onboarding completion")
        
        do {
            // Enable journal feature
            let settings = try Settings.getOrCreate(modelContext: modelContext)
            if !settings.journalEnabled {
                print("📔 Enabling journal feature")
                settings.journalEnabled = true
                try modelContext.save()
                
                // Post notification to show tool unlock celebration
                print("🎊 Triggering journal tool celebration")
                NotificationCenter.default.post(name: Notification.Name("JournalToolUnlocked"), object: nil)
            }
            
            // Transition to new chat with animation
            print("🔄 Transitioning to new chat")
            withAnimation(.easeInOut(duration: 0.3)) {
                onboardingViewModel = nil
            }
            
            // Small delay before starting new chat
            try? await Task.sleep(for: .seconds(0.3))
            startNewChat()
            
        } catch {
            print("❌ Error handling onboarding completion: \(error)")
        }
    }
}
