import SwiftUI

struct LaunchScreenView: View {
    var body: some View {
        GeometryReader { geometry in
            VStack {
                Spacer()
                
                // Container for both elements
                VStack(spacing: -min(geometry.size.width, geometry.size.height) * 0.05) {
                    // Asterisk
                    Image(systemName: "asterisk")
                        .font(.system(size: min(geometry.size.width, geometry.size.height) * 0.15))
                        .rotationEffect(.degrees(45))
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