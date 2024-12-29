import SwiftUI

/// A view modifier that adds a pulsing effect to SF Symbols.
///
/// This modifier uses the new iOS 17+ symbol effects to create a pulsing animation
/// that can be toggled on and off. It's particularly useful for indicating active states
/// or drawing attention to specific icons.
///
/// Usage:
/// ```swift
/// Image(systemName: "mic")
///     .modifier(PulseEffect(isActive: isRecording))
/// ```
struct PulseEffect: ViewModifier {
    /// Whether the pulse effect is active
    let isActive: Bool
    
    func body(content: Content) -> some View {
        if isActive {
            content.symbolEffect(.pulse.byLayer, options: .repeating)
        } else {
            content
        }
    }
}

// MARK: - View Extension
extension View {
    /// Applies a pulsing effect to a view when active
    /// - Parameter isActive: Whether the pulse effect should be shown
    /// - Returns: A view with the pulse effect applied
    func pulseEffect(isActive: Bool) -> some View {
        modifier(PulseEffect(isActive: isActive))
    }
} 