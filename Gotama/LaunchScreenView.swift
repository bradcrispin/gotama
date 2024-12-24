import SwiftUI

struct LaunchScreenView: View {
    var body: some View {
        GeometryReader { geometry in
            VStack {
                Spacer()
                
                // Container for both elements
                VStack(spacing: -min(geometry.size.width, geometry.size.height) * 0.05) {
                    // Asterisk
                    Text("*")
                        .font(.system(size: min(geometry.size.width, geometry.size.height) * 0.35))
                        .rotationEffect(.degrees(45))
                        .foregroundColor(.accentColor)
                        .offset(x: -min(geometry.size.width, geometry.size.height) * 0.03)
                    
                    // App name
                    Text("Gotama")
                        .font(.system(size: min(geometry.size.width, geometry.size.height) * 0.12))
                        .fontWeight(.medium)
                }
                .offset(y: -geometry.size.height * 0.05) // Move entire container up slightly
                
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(uiColor: .systemBackground))
        }
    }
}

#Preview {
    LaunchScreenView()
} 