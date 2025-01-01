import SwiftUI

/// A circular timer view that displays a countdown with a progress ring
struct CircularTimer: View {
    @Environment(\.colorScheme) private var colorScheme
    let timeRemaining: TimeInterval
    let duration: TimeInterval
    let isFirstOrLastPause: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button {
            onTap()
        } label: {
            ZStack {
                // Outer ring (background)
                Circle()
                    .stroke(
                        Color.gray.opacity(colorScheme == .dark ? 0.2 : 0.1),
                        style: StrokeStyle(
                            lineWidth: 3,
                            lineCap: .round
                        )
                    )
                
                // Progress ring
                Circle()
                    .trim(from: 0, to: timeRemaining / duration)
                    .stroke(
                        Color.accent.opacity(0.9),
                        style: StrokeStyle(
                            lineWidth: 3,
                            lineCap: .round
                        )
                    )
                    .rotationEffect(.degrees(-90))
                
                // Timer content
                ZStack {
                    // Bell icon - only show for first or last pause
                    if isFirstOrLastPause {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(Color.accent.opacity(0.6))
                            .offset(y: -36)
                    }
                    
                    Text(formattedTime)
                        .font(.system(size: 44, weight: .light, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .foregroundStyle(.primary.opacity(0.9))
                }
            }
            .frame(width: 160, height: 160)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private var formattedTime: String {
        let minutes = Int(timeRemaining) / 60
        let seconds = Int(timeRemaining) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
} 