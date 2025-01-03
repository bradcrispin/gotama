import SwiftUI

/// A cinematic text introduction view that appears on first app launch
struct IntroductionView: View {
    // Animation states for each text block
    @State private var showFirstText = false
    @State private var showSecondText = false
    @State private var showThirdText = false
    
    // Callback for when the intro is complete
    var onComplete: () -> Void
    
    var body: some View {
        ZStack {
            // Black background
            Color.black.ignoresSafeArea()
            
            // Center each text block in the same position
            ZStack {
                // First text
                Text("This is an invitation")
                    .opacity(showFirstText ? 1 : 0)
                    .animation(.easeInOut(duration: 2.0), value: showFirstText)
                
                // Second text
                Text("You can go on with your life")
                    .opacity(showSecondText ? 1 : 0)
                    .animation(.easeInOut(duration: 2.0), value: showSecondText)
                
                // Third text
                Text("Or you can become a sage...")
                    .opacity(showThirdText ? 1 : 0)
                    .animation(.easeInOut(duration: 2.0), value: showThirdText)
            }
            .font(.system(size: 28, weight: .light, design: .serif))
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 300) // Constrain width for better text wrapping
        }
        .onAppear {
            // Sequence the text animations
            Task { @MainActor in
                // Initial pause for dramatic effect
                try? await Task.sleep(for: .seconds(1.5))
                
                // First text appears
                showFirstText = true
                
                // Hold first text, then fade out
                try? await Task.sleep(for: .seconds(3.5))
                showFirstText = false
                
                // Longer pause between texts
                try? await Task.sleep(for: .seconds(1.5))
                showSecondText = true
                
                // Hold second text, then fade out
                try? await Task.sleep(for: .seconds(3.5))
                showSecondText = false
                
                // Longer pause between texts
                try? await Task.sleep(for: .seconds(1.5))
                showThirdText = true
                
                // Hold final text longer
                try? await Task.sleep(for: .seconds(3.5))
                showThirdText = false
                
                // Final pause before completion
                try? await Task.sleep(for: .seconds(1.5))
                onComplete()
            }
        }
    }
}

#Preview {
    IntroductionView(onComplete: {})
} 