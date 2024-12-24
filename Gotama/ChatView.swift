import SwiftUI
import SwiftData

struct ChatView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var chat: Chat?
    @State private var messageText: String = ""
    @State private var isLoading = false
    @FocusState private var isFocused: Bool
    @State private var errorMessage: String?
    @Query private var settings: [Settings]
    @State private var showSettingsOnAppear = false
    @State private var showSettings = false
    @State private var canCreateNewChat = false
    @Namespace private var animation
    @State private var asteriskRotation = 45.0
    @State private var isAsteriskAnimating = false
    @State private var scrollProxy: ScrollViewProxy?
    @State private var isNearBottom = true
    @State private var showScrollToBottom = false
    @State private var hasUserScrolled = false
    
    private let haptics = UIImpactFeedbackGenerator(style: .medium)
    private let softHaptics = UIImpactFeedbackGenerator(style: .soft)
    private let anthropic = AnthropicClient()
    
    private var isApiKeyConfigured: Bool {
        guard let settings = settings.first else {
            print("⚠️ No settings found")
            return false
        }
        print("🔑 API Key configured: \(!settings.anthropicApiKey.isEmpty)")
        print("🔑 API Key length: \(settings.anthropicApiKey.count)")
        return !settings.anthropicApiKey.isEmpty
    }
    
    init(chat: Chat?) {
        _chat = State(initialValue: chat)
    }
    
    private func sendMessage() {
        let trimmedText = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        
        haptics.impactOccurred()
        
        print("🔍 Checking API key configuration...")
        guard isApiKeyConfigured else {
            print("❌ API key not configured")
            errorMessage = "Please add your Anthropic API key"
            return
        }
        print("✅ API key configured, proceeding with message")
        
        if chat == nil {
            let newChat = Chat()
            let title = String(trimmedText.prefix(50)).trimmingCharacters(in: .whitespacesAndNewlines)
            newChat.title = title.isEmpty ? "New chat" : title
            modelContext.insert(newChat)
            chat = newChat
        }
        
        canCreateNewChat = false
        
        // Get previous messages before adding the new one
        let previousMessages = chat?.messages ?? []
        
        let userMessage = ChatMessage(role: "user", content: trimmedText, createdAt: Date())
        chat?.messages.append(userMessage)
        chat?.updatedAt = Date()
        messageText = ""
        
        let assistantMessage = ChatMessage(role: "assistant", content: "", createdAt: Date(), isTyping: true)
        chat?.messages.append(assistantMessage)
        
        isLoading = true
        hasUserScrolled = false // Reset scroll state for new message
        
        Task {
            do {
                var chunkCount = 0
                print("📤 Starting message stream...")
                
                print("📨 Sending message with \(previousMessages.count) previous messages:")
                for (index, msg) in previousMessages.enumerated() {
                    print("  \(index + 1). [\(msg.role)]: \(msg.content)")
                }
                print("📨 New message: \(trimmedText)")
                
                let stream = try await anthropic.sendMessage(trimmedText, previousMessages: previousMessages)
                
                let startTime = Date()
                for try await text in stream {
                    chunkCount += 1
                    if chunkCount == 1 {
                        let initialDelay = Date().timeIntervalSince(startTime)
                        print("⏱️ First chunk received after \(String(format: "%.2f", initialDelay))s")
                        await MainActor.run {
                            assistantMessage.isTyping = false
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
                        let beforeLength = assistantMessage.content.count
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
                        
                        print("📝 Updated content length: \(beforeLength) -> \(assistantMessage.content.count)")
                    }
                }
                
                let totalTime = Date().timeIntervalSince(startTime)
                print("✅ Stream completed: \(chunkCount) chunks in \(String(format: "%.2f", totalTime))s")
                print("📊 Average: \(String(format: "%.2f", Double(chunkCount)/totalTime)) chunks/second")
                
                await MainActor.run {
                    isLoading = false
                    canCreateNewChat = true
                    softHaptics.impactOccurred(intensity: 0.7)
                }
            } catch {
                print("❌ Stream error: \(error)")
                await MainActor.run {
                    assistantMessage.isTyping = false
                    handleError(error, for: assistantMessage)
                }
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if let error = errorMessage {
                ErrorBanner(message: error) {
                    if error.contains("API key") {
                        showSettings = true
                    }
                }
            }
            
            if let existingChat = chat, !existingChat.messages.isEmpty {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(existingChat.messages.sorted(by: { $0.createdAt < $1.createdAt })) { message in
                                MessageBubble(message: message, 
                                            onRetry: message.error != nil ? {
                                                await retryMessage(message)
                                            } : nil,
                                            showError: errorMessage == nil)
                                    .id(message.id)
                            }
                        }
                        .padding()
                        .onChange(of: existingChat.messages.count) { oldCount, newCount in
                            if !hasUserScrolled || isNearBottom {
                                withAnimation(.spring(duration: 0.3)) {
                                    proxy.scrollTo(existingChat.messages.last?.id, anchor: .bottom)
                                }
                            } else {
                                showScrollToBottom = true
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .overlay(alignment: .bottomTrailing) {
                        if showScrollToBottom {
                            Button {
                                withAnimation(.spring(duration: 0.3)) {
                                    proxy.scrollTo(existingChat.messages.last?.id, anchor: .bottom)
                                    showScrollToBottom = false
                                    hasUserScrolled = false
                                    isNearBottom = true
                                }
                            } label: {
                                Image(systemName: "arrow.down.circle.fill")
                                    .font(.title)
                                    .foregroundStyle(.accent)
                                    .background(.background)
                                    .clipShape(Circle())
                            }
                            .padding(.trailing, 16)
                            .padding(.bottom, 80)
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .onAppear {
                        scrollProxy = proxy
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            withAnimation(.spring(duration: 0.3)) {
                                proxy.scrollTo(existingChat.messages.last?.id, anchor: .bottom)
                            }
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
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                }
            } else {
                VStack(spacing: 24) {
                    Image(systemName: "asterisk")
                        .font(.largeTitle)
                        .foregroundStyle(.accent)
                        .rotationEffect(.degrees(asteriskRotation))
                        .matchedGeometryEffect(id: "asterisk", in: animation)
                        .onAppear {
                            startAsteriskAnimation()
                        }
                    
                    if let firstName = settings.first?.firstName, !firstName.isEmpty {
                        Text("Hi \(firstName). What is in your mind?")
                            .font(.title)
                            .multilineTextAlignment(.center)
                            .matchedGeometryEffect(id: "title", in: animation)
                    } else {
                        Text("What is in your mind?")
                            .font(.title)
                            .multilineTextAlignment(.center)
                            .matchedGeometryEffect(id: "title", in: animation)
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
                .transition(.asymmetric(insertion: .move(edge: .leading), removal: .opacity))
            }
        }
        .animation(.spring(duration: 0.4), value: chat?.messages.isEmpty)
        .animation(.spring(duration: 0.4), value: chat?.id)
        .navigationTitle("Gotama")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Text("")
                }
                .tint(.accent)
            }
            
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
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        startAsteriskAnimation()
                    }
                    
                    // Delay focus until after animation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        print("⌨️ Setting focus state to true")
                        isFocused = true
                        
                        // Additional delay for keyboard
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            print("⌨️ Forcing keyboard appearance")
                            UIApplication.shared.sendAction(#selector(UIResponder.becomeFirstResponder),
                                                         to: nil,
                                                         from: nil,
                                                         for: nil)
                        }
                    }
                } label: {
                    Image(systemName: "plus.message")
                }
                .disabled(!canCreateNewChat)
                .tint(.accent)
            }
        }
        .onAppear {
            if let chatId = chat?.id {
                print("📱 ChatView appeared for chat: \(chatId)")
            } else {
                print("📱 ChatView appeared for new chat")
                startAsteriskAnimation()
                isFocused = true
                
                UIApplication.shared.sendAction(#selector(UIResponder.becomeFirstResponder), 
                                             to: nil, 
                                             from: nil, 
                                             for: nil)
            }
            
            if let settings = settings.first {
                Task {
                    await anthropic.configure(with: settings.anthropicApiKey)
                }
            }
            
            if settings.first?.firstName.isEmpty ?? true || 
               settings.first?.anthropicApiKey.isEmpty ?? true {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showSettingsOnAppear = true
                }
            }
        }
        .onDisappear {
            if let chat = chat, chat.messages.isEmpty {
                modelContext.delete(chat)
            }
        }
        .sheet(isPresented: $showSettingsOnAppear) {
            SettingsView(focusApiKey: false)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(focusApiKey: true) {
                // Clear error if API key is now configured
                if isApiKeyConfigured {
                    errorMessage = nil
                }
            }
        }
    }
    
    @ViewBuilder
    private var inputArea: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                ZStack {
                    TextField("Chat with Gotama", text: $messageText, axis: .vertical)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .padding(.trailing, 44)
                        .focused($isFocused)
                        .disabled(isLoading)
                    
                    HStack {
                        Spacer()
                        Button {
                            sendMessage()
                        } label: {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.title2)
                                .foregroundColor(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading ? .secondary : .accent)
                        }
                        .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                        .padding(.trailing, 12)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background {
                VStack(spacing: 0) {
                    Color(white: 0.15)
                        .clipShape(UnevenRoundedRectangle(cornerRadii: 
                            .init(topLeading: 16, bottomLeading: 0, bottomTrailing: 0, topTrailing: 16)))
                    Color(white: 0.15)
                        .frame(maxHeight: .infinity)
                        .edgesIgnoringSafeArea(.bottom)
                }
            }
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
            
            let stream = try await anthropic.sendMessage(userMessage.content, previousMessages: previousMessages)
            
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
        
        withAnimation(.easeInOut(duration: 8)
            .repeatForever(autoreverses: false)) {
                asteriskRotation = 405 // 45 + 360 degrees
        }
    }
}

struct MessageBubble: View {
    let message: ChatMessage
    var onRetry: (() async -> Void)?
    let showError: Bool
    
    var body: some View {
        HStack {
            if message.role == "user" {
                Spacer()
            }
            
            VStack(alignment: message.role == "user" ? .trailing : .leading) {
                if message.isTyping == true {
                    TypingIndicator()
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                } else {
                    Text(message.content)
                        .textSelection(.enabled)
                        .padding(.vertical, 8)
                        .padding(.horizontal, message.role == "user" ? 12 : 16)
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
            .background(message.role == "user" ? Color(white: 0.1) : nil)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            
            if message.role == "assistant" {
                Spacer()
            }
        }
    }
}

struct TypingIndicator: View {
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
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.secondary)
            
            Text(message)
                .foregroundStyle(.secondary)
            
            Spacer()
        }
        .padding()
        .background(Color(white: 0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
        .padding(.top)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}