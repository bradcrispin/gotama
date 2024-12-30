import SwiftUI

/// A view component that displays a scrollable list of chat messages.
/// Handles message display, scrolling behavior, and scroll position tracking.
///
/// Features:
/// - Automatic scrolling to bottom for new messages
/// - User scroll position tracking
/// - Smooth animations and transitions
///
/// Usage:
/// ```swift
/// ChatScrollView(
///     messages: chat.messages,
///     hasUserScrolled: $hasUserScrolled,
///     isNearBottom: $isNearBottom,
///     showScrollToBottom: $showScrollToBottom,
///     messageText: $messageText,
///     viewOpacity: $viewOpacity,
///     onRetry: { await retryMessage($0) },
///     onScrollProxySet: { proxy in scrollProxy = proxy }
/// )
/// ```
struct ChatScrollView: View {
    // MARK: - Properties
    let messages: [ChatMessage]
    @Binding var hasUserScrolled: Bool
    @Binding var isNearBottom: Bool
    @Binding var showScrollToBottom: Bool
    @Binding var messageText: String
    @Binding var viewOpacity: Double
    let onRetry: (ChatMessage) async -> Void
    let onScrollProxySet: (ScrollViewProxy) -> Void
    
    // MARK: - Body
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(messages.sorted(by: { $0.createdAt < $1.createdAt })) { message in
                        ChatMessageBubble(
                            message: message,
                            onRetry: message.error != nil ? { await onRetry(message) } : nil,
                            showError: true,
                            messageText: $messageText,
                            showConfirmation: false
                        )
                        .id(message.id)
                        .transition(.opacity)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .onChange(of: messages.count) { oldCount, newCount in
                    print("📜 Messages count changed: \(oldCount) -> \(newCount)")
                    
                    if !hasUserScrolled || isNearBottom {
                        withAnimation(.spring(duration: 0.3)) {
                            proxy.scrollTo(messages.last?.id, anchor: .bottom)
                        }
                        print("🔄 Auto-scrolling to bottom")
                    } else {
                        showScrollToBottom = true
                        print("⚠️ User has scrolled up, showing scroll button")
                    }
                }
            }
            .opacity(viewOpacity)
            .onAppear {
                onScrollProxySet(proxy)
                if let lastUserMessage = messages.last(where: { $0.role == "user" }) {
                    proxy.scrollTo(lastUserMessage.id, anchor: .top)
                    print("📍 Scrolling to last user message")
                }
            }
            .simultaneousGesture(
                DragGesture().onChanged { value in
                    // Consider user near bottom if they're within 100 points of bottom
                    let threshold: CGFloat = 100
                    let scrollViewHeight = UIScreen.main.bounds.height
                    let bottomEdge = value.location.y
                    let wasNearBottom = isNearBottom
                    isNearBottom = (scrollViewHeight - bottomEdge) < threshold
                    
                    if wasNearBottom != isNearBottom {
                        print("📍 Near bottom changed: \(wasNearBottom) -> \(isNearBottom)")
                    }
                    
                    if !hasUserScrolled && value.translation.height > 0 {
                        hasUserScrolled = true
                        print("👆 User started scrolling")
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
        }
    }
}

// MARK: - Previews
#Preview {
    ChatScrollView(
        messages: [
            ChatMessage(role: "user", content: "Hello!", createdAt: Date()),
            ChatMessage(role: "assistant", content: "Hi there!", createdAt: Date())
        ],
        hasUserScrolled: .constant(false),
        isNearBottom: .constant(true),
        showScrollToBottom: .constant(false),
        messageText: .constant(""),
        viewOpacity: .constant(1.0),
        onRetry: { _ in },
        onScrollProxySet: { _ in }
    )
} 