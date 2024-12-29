import SwiftUI

/// A view component that displays a scrollable list of chat messages.
/// Handles message display, scrolling behavior, and scroll position tracking.
///
/// Features:
/// - Lazy loading of messages
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
    /// The messages to display
    let messages: [ChatMessage]
    /// Whether the user has manually scrolled
    @Binding var hasUserScrolled: Bool
    /// Whether the scroll position is near the bottom
    @Binding var isNearBottom: Bool
    /// Whether to show the scroll to bottom button
    @Binding var showScrollToBottom: Bool
    /// The current message text (for editing)
    @Binding var messageText: String
    /// The view's opacity
    @Binding var viewOpacity: Double
    /// Callback for retrying failed messages
    let onRetry: (ChatMessage) async -> Void
    /// Callback for setting the scroll proxy
    let onScrollProxySet: (ScrollViewProxy) -> Void
    
    // Track content size changes
    @State private var contentHeight: CGFloat = 0
    @State private var scrollViewHeight: CGFloat = 0
    
    // MARK: - Body
    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView {
                    // Content size tracking view
                    GeometryReader { contentGeometry in
                        Color.clear.preference(
                            key: ContentSizePreferenceKey.self,
                            value: contentGeometry.size
                        )
                    }
                    
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
                            .transition(.opacity.combined(with: .scale))
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .onChange(of: messages.count) { oldCount, newCount in
                        print("📜 Messages count changed: \(oldCount) -> \(newCount)")
                        print("📏 Content height: \(contentHeight), ScrollView height: \(scrollViewHeight)")
                        
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
                // Fix the frame to prevent resizing
                .frame(
                    maxWidth: .infinity,
                    maxHeight: geometry.size.height,
                    alignment: .bottom
                )
                .onAppear {
                    scrollViewHeight = geometry.size.height
                    onScrollProxySet(proxy)
                    if let lastUserMessage = messages.last(where: { $0.role == "user" }) {
                        proxy.scrollTo(lastUserMessage.id, anchor: .top)
                        print("📍 Scrolling to last user message")
                    }
                }
                .onChange(of: geometry.size) { oldSize, newSize in
                    print("📐 ScrollView size changed: \(oldSize) -> \(newSize)")
                    scrollViewHeight = newSize.height
                }
                .simultaneousGesture(
                    DragGesture().onChanged { value in
                        let threshold: CGFloat = 100
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
}

// MARK: - Preference Key for Content Size
private struct ContentSizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
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