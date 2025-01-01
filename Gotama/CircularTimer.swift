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
                // Bell icon - only show for first or last pause
                if isFirstOrLastPause {
                    HStack {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.secondary.opacity(0.6))
                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .zIndex(0)
                }
                
                // Center timer
                ZStack {
                    // Progress ring
                    Circle()
                        .trim(from: 0, to: timeRemaining / duration)
                        .stroke(
                            Color.blue.opacity(0.9),
                            style: StrokeStyle(
                                lineWidth: 2,
                                lineCap: .round
                            )
                        )
                        .rotationEffect(.degrees(-90))
                    
                    // Timer content
                    VStack(spacing: 6) {
                        Text(formattedTime)
                            .font(.system(size: 32, weight: .medium, design: .rounded))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                            .foregroundStyle(.primary.opacity(0.9))
                    }
                    .frame(maxHeight: .infinity)
                }
                .frame(width: 120, height: 120)
                .zIndex(1)
            }
            .frame(maxWidth: .infinity)
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