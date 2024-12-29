import SwiftUI

/// A view modifier that adds a continuous rotation animation.
/// Useful for loading indicators and other spinning elements.
struct RotationAnimation: ViewModifier {
    /// The current rotation angle in degrees
    @Binding var rotation: Double
    /// Whether the animation is currently active
    @Binding var isAnimating: Bool
    /// The speed of rotation in seconds per revolution
    let duration: Double
    /// The starting angle in degrees
    let startAngle: Double
    
    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(rotation))
            .onChange(of: isAnimating) { wasAnimating, isNowAnimating in
                if isNowAnimating {
                    startAnimation()
                }
            }
    }
    
    private func startAnimation() {
        // Reset rotation to starting position
        rotation = startAngle
        withAnimation(.easeInOut(duration: duration)
            .repeatForever(autoreverses: false)) {
                rotation = startAngle + 360 // One full rotation
            }
    }
}

/// A view modifier that adds a fade transition animation.
struct FadeTransition: ViewModifier {
    /// The opacity value to animate
    @Binding var opacity: Double
    /// The duration of the animation in seconds
    let duration: Double
    
    func body(content: Content) -> some View {
        content
            .opacity(opacity)
            .animation(.easeInOut(duration: duration), value: opacity)
    }
}

/// A view modifier that adds a scale animation.
struct ScaleAnimation: ViewModifier {
    /// The current scale factor
    @State private var scale: CGFloat = 1.0
    /// Whether the animation is active
    let isActive: Bool
    /// The target scale factor
    let targetScale: CGFloat
    /// The animation duration in seconds
    let duration: Double
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .onChange(of: isActive) { wasActive, isNowActive in
                if isNowActive {
                    withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
                        scale = targetScale
                    }
                } else {
                    withAnimation(.easeInOut(duration: duration)) {
                        scale = 1.0
                    }
                }
            }
    }
}

// MARK: - View Extensions
extension View {
    /// Applies a continuous rotation animation
    func rotationAnimation(
        rotation: Binding<Double>,
        isAnimating: Binding<Bool>,
        duration: Double = 8.0,
        startAngle: Double = 45
    ) -> some View {
        modifier(RotationAnimation(
            rotation: rotation,
            isAnimating: isAnimating,
            duration: duration,
            startAngle: startAngle
        ))
    }
    
    /// Applies a fade transition animation
    func fadeTransition(
        opacity: Binding<Double>,
        duration: Double = 0.3
    ) -> some View {
        modifier(FadeTransition(
            opacity: opacity,
            duration: duration
        ))
    }
    
    /// Applies a scale animation
    func scaleAnimation(
        isActive: Bool,
        targetScale: CGFloat = 1.2,
        duration: Double = 1.0
    ) -> some View {
        modifier(ScaleAnimation(
            isActive: isActive,
            targetScale: targetScale,
            duration: duration
        ))
    }
}

// MARK: - Previews
struct AnimationModifiers_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 30) {
            // Rotation animation preview
            Image(systemName: "asterisk")
                .font(.title)
                .rotationAnimation(
                    rotation: .constant(45),
                    isAnimating: .constant(true)
                )
            
            // Fade transition preview
            Text("Fade Me")
                .fadeTransition(
                    opacity: .constant(0.5)
                )
            
            // Scale animation preview
            Image(systemName: "heart.fill")
                .font(.title)
                .foregroundColor(.red)
                .scaleAnimation(isActive: true)
        }
        .padding()
    }
} 