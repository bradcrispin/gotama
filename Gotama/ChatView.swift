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
    @State private var asteriskAnimationSpeed = 8.0  // Default speed in seconds
    @State private var asteriskAnimationState = 0  // 0: normal, 1: slow, 2: stopped
    @State private var scrollProxy: ScrollViewProxy?
    @State private var isNearBottom = true
    @State private var showScrollToBottom = false
    @State private var hasUserScrolled = false
    @State private var isRecording = false
    @State private var speechRecognizer: SFSpeechRecognizer? = SFSpeechRecognizer()
    @State private var recognitionTask: SFSpeechRecognitionTask?
    @State private var audioEngine = AVAudioEngine()
    @State private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    @State private var currentTask: Task<Void, Never>?
    @State private var pendingMessageText: String?
    @State private var viewOpacity: Double = 0.0
    @State private var hasAppliedInitialAnimation = false
    @State private var isFirstLaunch = true  // New state variable
    @State private var onboardingViewModel: OnboardingViewModel?
    
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
                ErrorBanner(message: error) {
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
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(existingChat.messages.sorted(by: { $0.createdAt < $1.createdAt })) { message in
                                MessageBubble(
                                    message: message,
                                    onRetry: message.error != nil ? { await retryMessage(message) } : nil,
                                    showError: errorMessage == nil,
                                    messageText: $messageText,
                                    showConfirmation: false
                                )
                                .id(message.id)
                                .transition(.opacity.combined(with: .scale))
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .onChange(of: existingChat.messages.count) { oldCount, newCount in
                            if !hasUserScrolled || isNearBottom {
                                withAnimation(.spring(duration: 0.3)) {
                                    proxy.scrollTo(existingChat.messages.last?.id, anchor: .bottom)
                                }
                            } else {
                                showScrollToBottom = true
                            }
                        }
                        .animation(.smooth(duration: 0.3), value: existingChat.messages)
                    }
                    .opacity(viewOpacity)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .onAppear {
                        scrollProxy = proxy
                        if let lastUserMessage = existingChat.messages.last(where: { $0.role == "user" }) {
                            proxy.scrollTo(lastUserMessage.id, anchor: .top)
                        }
                    }
                    .simultaneousGesture(
                        DragGesture().onChanged { value in
                            let threshold: CGFloat = 100
                            let scrollViewHeight = UIScreen.main.bounds.height
                            let bottomEdge = value.location.y
                            isNearBottom = (scrollViewHeight - bottomEdge) < threshold
                            
                            if !hasUserScrolled && value.translation.height > 0 {
                                hasUserScrolled = true
                            }
                            
                            showScrollToBottom = !isNearBottom && hasUserScrolled
                        }
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
                    .transition(.opacity.animation(.easeInOut(duration: 0.3)))
                }
            } 
            // If there's no chat, show the onboarding view or the
            else {
                VStack(spacing: 24) {
                    Image(systemName: "asterisk")
                        .font(.largeTitle)
                        .foregroundStyle(.accent)
                        .rotationEffect(.degrees(asteriskRotation))
                        .matchedGeometryEffect(id: "asterisk", in: animation)
                        .onAppear {
                            startAsteriskAnimation()
                        }
                    
                    if let viewModel = onboardingViewModel {
                        VStack(spacing: 16) {
                            if viewModel.showMessages, let step = viewModel.currentStep {
                                ForEach(Array(step.content.messages.enumerated()), id: \.offset) { index, message in
                                    Text(message)
                                        .font(.title)
                                        .multilineTextAlignment(.center)
                                        .opacity(Double(index) <= viewModel.messageAnimationProgress ? 1 : 0)
                                        .transition(.move(edge: .bottom).combined(with: .opacity))
                                        .animation(.easeOut(duration: 0.8), value: viewModel.messageAnimationProgress)
                                }
                            }
                        }
                        .frame(maxWidth: 300)
                        .opacity(viewModel.viewOpacity)
                        .onChange(of: viewModel.isComplete) { wasComplete, isComplete in
                            if isComplete {
                                Task { @MainActor in
                                    await handleOnboardingCompletion()
                                }
                            }
                        }
                    } else if let firstName = settings.first?.firstName, !firstName.isEmpty {
                        Text("Hi \(firstName). What is in your mind?")
                            .font(.title)
                            .multilineTextAlignment(.center)
                            .matchedGeometryEffect(id: "greeting", in: animation)
                            .frame(maxWidth: 300)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.background)
                .onTapGesture {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                                 to: nil,
                                                 from: nil,
                                                 for: nil)
                }
                .safeAreaInset(edge: .bottom) {
                    inputArea
                }
                .transition(.opacity.animation(.easeInOut(duration: 0.3)))
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
                    HStack(spacing: 4) {
                        Text("Gotama")
                            // .font(.headline)
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                        Image(systemName: "chevron.down")
                            .font(.caption)
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
    }
    
    // Chat input area
    @ViewBuilder
    private var inputArea: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Wrap TextField and button in a container
                HStack(spacing: 0) {
                    TextField(onboardingViewModel?.currentStep?.content.inputPlaceholder ?? "Chat with Gotama",
                             text: $messageText, axis: .vertical)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .focused($isFocused)
                        .disabled(isLoading)
                        .opacity(onboardingViewModel?.showInput ?? true ? 1 : 0)
                        .foregroundColor(isRecording ? .white : (messageText.isEmpty ? (colorScheme == .dark ? .secondary : .primary.opacity(0.9)) : .primary))
                        .textFieldStyle(.plain)
                        .onChange(of: messageText) { oldValue, newValue in
                            print("💬 Message text changed: '\(oldValue)' -> '\(newValue)'")
                            print("🎤 Recording state: \(isRecording), isTextFromRecognition: \(isTextFromRecognition)")
                            if isRecording && !isTextFromRecognition {
                                stopDictation()
                            }
                        }
                    
                    Button {
                        if isLoading {
                            stopGeneration()
                        } else if isRecording {
                            stopDictation()
                        } else if messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            startDictation()
                        } else {
                            sendMessage()
                        }
                    } label: {
                        Image(systemName: isLoading ? "stop.circle.fill" :
                              (isRecording ? "mic.fill" : 
                               (messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "mic" : "arrow.up.circle.fill")))
                            .font(.title2)
                            .foregroundColor(isLoading ? Color(white: 0.6) : (isRecording ? .white : .accent))
                            .symbolEffect(.bounce, value: isRecording)
                            .modifier(PulseEffect(isActive: isRecording))
                    }
                    .padding(.horizontal, 12)
                }
                .contentShape(Rectangle())
                .simultaneousGesture(
                    TapGesture()
                        .onEnded { _ in
                            print("👆 Input area tapped, current focus state: \(isFocused)")
                            guard !isFocused else { return }
                            Task { @MainActor in
                                try? await Task.sleep(for: .nanoseconds(1))  // Minimal delay to ensure view is ready
                                print("⌨️ Setting focus after tap")
                                withAnimation(.easeOut(duration: 0.2)) {
                                    isFocused = true
                                }
                            }
                        }
                )
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background {
                ZStack {
                    //   layer - always opaque
                    VStack(spacing: 0) {
                        Group {
                            colorScheme == .dark ? Color(white: 0.23) : Color(.systemGray4)
                        }
                        .clipShape(UnevenRoundedRectangle(cornerRadii: 
                            .init(topLeading: 16, bottomLeading: 0, bottomTrailing: 0, topTrailing: 16)))
                        
                        Group {
                            colorScheme == .dark ? Color(white: 0.23) : Color(.systemGray4)
                        }
                        .frame(maxHeight: .infinity)
                        .edgesIgnoringSafeArea(.bottom)
                    }
                    
                    // Accent color layer when recording
                    if isRecording {
                        VStack(spacing: 0) {
                            Color.accent
                                .opacity(0.8)
                                .clipShape(UnevenRoundedRectangle(cornerRadii: 
                                    .init(topLeading: 16, bottomLeading: 0, bottomTrailing: 0, topTrailing: 16)))
                            
                            Color.accent
                                .opacity(0.8)
                                .frame(maxHeight: .infinity)
                                .edgesIgnoringSafeArea(.bottom)
                        }
                        .transition(.opacity)
                    }
                }
                .onChange(of: isRecording) { wasRecording, isNowRecording in
                    // print("🎙️ Recording state changed: \(wasRecording) -> \(isNowRecording)")
                }
            }
            .opacity(viewOpacity)
            .animation(.easeOut(duration: 0.2), value: viewOpacity)
        }
    }
    
    private func handleError(_ error: Error, for message: ChatMessage) {
        message.error = error.localizedDescription
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
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            errorMessage = "Speech recognition is not available at this time"
            return
        }
        
        // First check microphone permission
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission { granted in
                DispatchQueue.main.async {
                    if !granted {
                        self.errorMessage = "Tap here to enable microphone access in Settings"
                        return
                    }
                    self.checkSpeechRecognitionPermission()
                }
            }
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                DispatchQueue.main.async {
                    if !granted {
                        self.errorMessage = "Tap here to enable microphone access in Settings"
                        return
                    }
                    self.checkSpeechRecognitionPermission()
                }
            }
        }
    }
    
    private func checkSpeechRecognitionPermission() {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    if self.isRecording {
                        self.stopDictation()
                    } else {
                        do {
                            try self.startRecording()
                        } catch {
                            self.errorMessage = "Failed to start recording: \(error.localizedDescription)"
                            print("Failed to start recording: \(error)")
                        }
                    }
                case .denied:
                    self.errorMessage = "Tap here to enable speech recognition in Settings"
                case .restricted:
                    self.errorMessage = "Speech recognition is restricted on this device"
                case .notDetermined:
                    self.errorMessage = "Speech recognition not yet authorized"
                @unknown default:
                    self.errorMessage = "Speech recognition not available"
                }
            }
        }
    }
    
    private func startRecording() throws {
        // Cancel existing task and request
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw NSError(domain: "SpeechRecognition", code: -1, 
                         userInfo: [NSLocalizedDescriptionKey: "Unable to create recognition request"])
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        // For on-device recognition
        if #available(iOS 13, *) {
            recognitionRequest.requiresOnDeviceRecognition = true
        }
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { result, error in
            if let result = result {
                let transcribedText = result.bestTranscription.formattedString
                
                // Only update if the transcription has actual content
                if !transcribedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    DispatchQueue.main.async {
                        print("🎤 Speech recognition update: \(transcribedText)")
                        self.isTextFromRecognition = true
                        self.messageText = transcribedText
                        
                        // Add a small delay before resetting the flag
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            self.isTextFromRecognition = false
                        }
                    }
                } else {
                    print("🎤 Ignoring empty transcription")
                }
            }
            
            if error != nil || (result?.isFinal ?? false) {
                print("🎤 Speech recognition ended: \(error?.localizedDescription ?? "Final result")")
                self.stopDictation()
            }
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        
        withAnimation {
            isRecording = true
        }
        
        softHaptics.impactOccurred()
    }
    
    private func stopDictation() {
        // Cancel recognition task first
        recognitionTask?.finish()
        recognitionTask = nil
        
        // End audio request
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        // Stop audio engine last
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        withAnimation {
            isRecording = false
        }
        
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

struct MessageBubble: View {
    @Environment(\.colorScheme) private var colorScheme
    let message: ChatMessage
    var onRetry: (() async -> Void)?
    let showError: Bool
    @State private var showCopied = false
    @State private var showDeleteConfirmation = false
    @State private var showEditConfirmation = false
    @Environment(\.modelContext) private var modelContext
    
    // Add binding to messageText from ChatView
    @Binding var messageText: String
    let showConfirmation: Bool
    
    var body: some View {
        HStack {
            if message.role == "user" {
                Spacer()
            }
            
            VStack(alignment: message.role == "user" ? .trailing : .leading, spacing: 8) {
                if message.isThinking == true {
                    ThinkingIndicator()
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                } else {
                    Text(message.content)
                        .textSelection(.enabled)
                        .padding(.vertical, 8)
                        .padding(.horizontal, message.role == "user" ? 12 : 16)
                        .contextMenu(menuItems: {
                            Button {
                                UIPasteboard.general.string = message.content
                            } label: {
                                Label("Copy", systemImage: "doc.on.doc")
                            }
                            
                            if message.role == "user" {
                                Button {
                                    editMessage()
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                
                                Button(role: .destructive) {
                                    deleteMessageAndFollowing()
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        })
                    
                    if showConfirmation {
                        HStack(spacing: 12) {
                            Button {
                                messageText = "Yes"
                            } label: {
                                Text("Yes")
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.accent)
                                    .foregroundColor(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                            }
                            
                            Button {
                                messageText = "No"
                            } label: {
                                Text("No")
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color(.systemGray5))
                                    .foregroundColor(.primary)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                            }
                        }
                        .padding(.top, 4)
                    }
                }
                
                if showError, let error = message.error {
                    HStack(spacing: 8) {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        if let onRetry {
                            Button {
                                Task {
                                    await onRetry()
                                }
                            } label: {
                                Image(systemName: "arrow.clockwise")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .background(message.role == "user" ? (colorScheme == .dark ? Color(white: 0.15) : Color(white: 0.93)) : nil)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            
            if message.role == "assistant" {
                Spacer()
            }
        }
        .alert("Edit Message", isPresented: $showEditConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Edit", role: .destructive) {
                editMessage()
            }
        } message: {
            Text("Editing and resending this message will delete all messages that follow")
        }
        .alert("Delete Message", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteMessageAndFollowing()
            }
        } message: {
            Text("Deleting this message will delete all messages that follow")
        }
    }
    
    private func editMessage() {
        print("✏️ Starting message edit")
        
        // Set the message text for editing
        messageText = message.content
        print("📝 Loaded message text for editing: \(messageText)")
        
        // Check if this is the first message and update chat title
        if let chat = message.chat,
           let firstMessage = chat.messages.first,
           firstMessage.id == message.id {
            chat.title = messageText
        }
        
        // Delete this and following messages
        deleteMessageAndFollowing()
    }
    
    private func deleteMessageAndFollowing() {
        guard let chat = message.chat else {
            print("❌ Delete failed: No chat associated with message")
            return
        }
        
        // Find the index of the current message
        guard let currentIndex = chat.messages.firstIndex(where: { $0.id == message.id }) else {
            print("❌ Delete failed: Could not find message index in chat")
            return
        }
        
        print("🗑️ Deleting message at index \(currentIndex) and \(chat.messages.count - currentIndex - 1) following messages")
        
        // Get all messages from current to end
        let messagesToDelete = Array(chat.messages[currentIndex...])
        print("📝 Messages to delete: \(messagesToDelete.count)")
        
        // Remove messages from chat's messages array first
        withAnimation {
            chat.messages.removeSubrange(currentIndex...)
        }
        
        // Then delete from model context
        for message in messagesToDelete {
            print("🗑️ Deleting message: \(message.id)")
            modelContext.delete(message)
        }
        
        print("🗑️ Deletion complete. Remaining messages: \(chat.messages.count)")
    }
}

struct ThinkingIndicator: View {
    @State private var rotation = 0.0
    
    var body: some View {
        Image(systemName: "asterisk")
            .font(.title3)
            .foregroundStyle(.accent)
            .rotationEffect(.degrees(rotation))
            .onAppear {
                withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
    }
}

struct ErrorBanner: View {
    let message: String
    var onTap: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(colorScheme == .dark ? .secondary : .secondary)
            
            Text(message)
                .foregroundStyle(colorScheme == .dark ? .secondary : .secondary)
            
            Spacer()
        }
        .padding()
        .background(colorScheme == .dark ? Color(white: 0.1) : Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
        .padding(.top)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}

struct PulseEffect: ViewModifier {
    let isActive: Bool
    
    func body(content: Content) -> some View {
        if isActive {
            content.symbolEffect(.pulse.byLayer, options: .repeating)
        } else {
            content
        }
    }
}
