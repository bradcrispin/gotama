import SwiftUI

/// A view component that displays an animated asterisk to indicate that the AI is thinking.
///
/// Features:
/// - Continuous rotation animation
/// - Accent color styling
/// - Compact design
///
/// The animation starts automatically when the view appears and continues until the view is removed.
///
/// Usage:
/// ```swift
/// ChatThinkingIndicator()
///     .padding()
/// ```
struct ChatThinkingIndicator: View {
    // MARK: - State
    /// Current rotation angle in degrees
    @State private var rotation = 0.0
    
    // MARK: - Body
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

#Preview {
    ChatThinkingIndicator()
} 