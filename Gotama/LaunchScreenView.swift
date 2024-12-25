import SwiftUI

struct LaunchScreenView: View {
    @State private var asteriskRotation = 45.0
    @State private var isAnimating = false
    
    var body: some View {
        GeometryReader { geometry in
            VStack {
                Spacer()
                
                // Container for both elements
                VStack(spacing: -min(geometry.size.width, geometry.size.height) * 0.05) {
                    // Asterisk
                    Image(systemName: "asterisk")
                        .font(.system(size: min(geometry.size.width, geometry.size.height) * 0.15))
                        .rotationEffect(.degrees(asteriskRotation))
                        .foregroundStyle(.accent)
                        .padding(27)
                    
                    // App name
                    Text("Gotama")
                        .font(.system(size: min(geometry.size.width, geometry.size.height) * 0.12))
                        .fontWeight(.medium)
                }
                .offset(y: -geometry.size.height * 0.05)
                
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(uiColor: .systemBackground))
            .onAppear {
                // Set environment variable to indicate we're coming from launch screen
                setenv("FROM_LAUNCH_SCREEN", "true", 1)
                
                // Start the rotation animation
                withAnimation(.easeInOut(duration: 8)
                    .repeatForever(autoreverses: false)) {
                    asteriskRotation = 405 // 45 + 360 degrees
                }
            }
            .onDisappear {
                // Clear the environment variable when launch screen disappears
                unsetenv("FROM_LAUNCH_SCREEN")
            }
        }
    }
}

#Preview {
    LaunchScreenView()
} 