import SwiftUI

/// A view component that displays error messages in a tappable banner.
///
/// Features:
/// - Adaptive dark/light mode styling
/// - Warning icon
/// - Tappable area for error resolution
/// - Rounded corners and padding
///
/// The banner is designed to be displayed at the top of the chat interface
/// and can trigger actions when tapped, such as opening settings.
///
/// Usage:
/// ```swift
/// ChatErrorBanner(message: "API key required") {
///     showSettings = true
/// }
/// ```
struct ChatErrorBanner: View {
    // MARK: - Properties
    /// The error message to display
    let message: String
    /// Callback executed when the banner is tapped
    var onTap: () -> Void
    
    // MARK: - Environment
    @Environment(\.colorScheme) private var colorScheme
    
    // MARK: - Body
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

#Preview {
    ChatErrorBanner(message: "An error occurred", onTap: {})
} 