import SwiftUI
import SwiftData

/// A view component that displays the empty state of the chat interface.
/// Shows an animated asterisk and welcome message or onboarding content.
///
/// Features:
/// - Animated asterisk with continuous rotation
/// - Personalized welcome message
/// - Support for onboarding content
/// - Smooth animations and transitions
///
/// Usage:
/// ```swift
/// ChatEmptyState(
///     firstName: settings.firstName,
///     asteriskRotation: $rotation,
///     onboardingViewModel: viewModel
/// )
/// ```
struct ChatEmptyState: View {
    // MARK: - Properties
    /// Optional user's first name for personalized greeting
    let firstName: String?
    /// Binding to control the asterisk's rotation animation
    @Binding var asteriskRotation: Double
    /// Optional onboarding view model for new users
    let onboardingViewModel: OnboardingViewModel?
    /// Binding to control animation state
    @Binding var isAnimating: Bool
    
    // MARK: - Animation Properties
    @Namespace private var animation
    
    // MARK: - Body
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "asterisk")
                .font(.largeTitle)
                .foregroundStyle(.accent)
                .rotationAnimation(
                    rotation: $asteriskRotation,
                    isAnimating: .init(
                        get: { isAnimating },
                        set: { isAnimating = $0 }
                    ),
                    duration: 8.0,
                    startAngle: isAnimating ? asteriskRotation : asteriskRotation
                )
                .matchedGeometryEffect(id: "asterisk", in: animation)
                .onAppear { 
                    // print("ChatEmptyState: Starting animation")
                    isAnimating = true 
                }
                .onTapGesture {
                    isAnimating.toggle()
                    // print("ChatEmptyState: Tap detected - Animation state: \(isAnimating)")
                }
                .opacity(isAnimating ? 1.0 : 0.6) // Visual feedback for paused state
                .contentShape(Rectangle()) // Ensures the entire area is tappable
            
            if let viewModel = onboardingViewModel {
                VStack(spacing: 16) {
                    if viewModel.showMessages, let step = viewModel.currentStep {
                        ForEach(Array(step.content.messages.enumerated()), id: \.offset) { index, message in
                            Text(message)
                                .font(.title)
                                .multilineTextAlignment(.center)
                                .fadeTransition(
                                    opacity: .constant(Double(index) <= viewModel.messageAnimationProgress ? 1 : 0),
                                    duration: 0.8
                                )
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                }
                .frame(maxWidth: 300)
                .fadeTransition(opacity: .constant(viewModel.viewOpacity))
            } else if let firstName = firstName, !firstName.isEmpty {
                Text("Hi \(firstName). What is in your mind?")
                    .font(.title)
                    .multilineTextAlignment(.center)
                    .matchedGeometryEffect(id: "greeting", in: animation)
                    .frame(maxWidth: 300)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
    }
}

// MARK: - Previews
#Preview("Empty State") {
    ChatEmptyState(
        firstName: "John",
        asteriskRotation: .constant(45),
        onboardingViewModel: nil,
        isAnimating: .constant(true)
    )
}

#Preview("Onboarding") {
    ChatEmptyState(
        firstName: nil,
        asteriskRotation: .constant(45),
        onboardingViewModel: OnboardingViewModel(modelContext: try! ModelContainer(for: Settings.self).mainContext),
        isAnimating: .constant(true)
    )
} 