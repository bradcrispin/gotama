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
        
        print("🔍 Checking API key configuration...")
        guard isApiKeyConfigured else {
            print("❌ API key not configured")
            errorMessage = "Please add your Anthropic API key in settings"
            return
        }
        print("✅ API key configured, proceeding with message")
        
        if chat == nil {
            let newChat = Chat()
            modelContext.insert(newChat)
            chat = newChat
        }
        
        let userMessage = ChatMessage(role: "user", content: trimmedText)
        chat?.messages.append(userMessage)
        chat?.updatedAt = Date()
        messageText = ""
        
        let assistantMessage = ChatMessage(role: "assistant", content: "", isTyping: true)
        chat?.messages.append(assistantMessage)
        
        isLoading = true
        
        Task {
            do {
                var responseText = ""
                let stream = try await anthropic.sendMessage(trimmedText, previousMessages: Array(chat?.messages.dropLast() ?? []))
                
                for try await text in stream {
                    responseText += text
                    assistantMessage.content = responseText
                }
                
                assistantMessage.isTyping = false
                isLoading = false
            } catch {
                assistantMessage.isTyping = false
                handleError(error, for: assistantMessage)
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if let error = errorMessage {
                ErrorBanner(message: error) {
                    if let lastMessage = chat?.messages.last,
                       lastMessage.error != nil {
                        Task {
                            await retryMessage(lastMessage)
                        }
                    }
                }
            }
            
            if let existingChat = chat, !existingChat.messages.isEmpty {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(existingChat.messages) { message in
                            MessageBubble(message: message, 
                                         onRetry: message.error != nil ? {
                                             await retryMessage(message)
                                         } : nil,
                                         showError: errorMessage == nil)
                        }
                    }
                    .padding()
                }
            } else {
                VStack(spacing: 24) {
                    Image(systemName: "asterisk")
                        .font(.largeTitle)
                        .foregroundStyle(.accent)
                        .rotationEffect(.degrees(45))
                    
                    Text("What is in your mind?")
                        .font(.title)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.background)
            }
            
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
                            if isLoading {
                                ProgressView()
                                    .padding(.trailing, 16)
                            } else {
                                Button(action: sendMessage) {
                                    Image(systemName: "arrow.up.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.accent)
                                }
                                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                .padding(.trailing, 12)
                            }
                        }
                    }
                    .background(Color(white: 0.15))
                    .clipShape(UnevenRoundedRectangle(cornerRadii: RectangleCornerRadii(topLeading: 20,  bottomLeading: 0, bottomTrailing: 0, topTrailing: 20)))
                }
            }
            .ignoresSafeArea(.keyboard)
        }
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
        }
        .onAppear {
            if let chatId = chat?.id {
                print("📱 ChatView appeared for chat: \(chatId)")
            } else {
                print("📱 ChatView appeared for new chat")
            }
            
            if let settings = settings.first, !settings.anthropicApiKey.isEmpty {
                print("🔄 Configuring AnthropicClient with API key")
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
        .task {
            isFocused = true
            
            UIApplication.shared.sendAction(#selector(UIResponder.becomeFirstResponder), 
                                         to: nil, 
                                         from: nil, 
                                         for: nil)
        }
        .sheet(isPresented: $showSettingsOnAppear) {
            SettingsView()
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
        
        message.error = nil
        message.content = ""
        isLoading = true
        
        do {
            var responseText = ""
            let previousMessages = Array(chat?.messages.prefix(while: { $0 !== message }) ?? [])
            let stream = try await anthropic.sendMessage(userMessage.content, previousMessages: previousMessages)
            
            for try await text in stream {
                responseText += text
                message.content = responseText
            }
            
            isLoading = false
        } catch {
            handleError(error, for: message)
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
                } else {
                    Text(message.content)
                        .textSelection(.enabled)
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
                }
            }
            .padding()
            .background(message.role == "user" ? Color(white: 0.1) : nil)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            
            if message.role == "assistant" {
                Spacer()
            }
        }
    }
}

struct TypingIndicator: View {
    @State private var dotCount = 0
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(.secondary)
                    .frame(width: 6, height: 6)
                    .opacity(dotCount >= index ? 1 : 0.3)
            }
        }
        .onAppear {
            withAnimation(Animation.easeInOut(duration: 0.6).repeatForever()) {
                dotCount = 3
            }
        }
    }
}

struct ErrorBanner: View {
    let message: String
    var onRetry: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.secondary)
            
            Text(message)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Button(action: onRetry) {
                Image(systemName: "arrow.clockwise")
                    .foregroundStyle(.accent)
            }
        }
        .padding()
        .background(Color(white: 0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
        .padding(.top)
    }
} 