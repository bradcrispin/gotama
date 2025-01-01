import SwiftUI
import SwiftData
import AudioToolbox
import MediaPlayer

/// A view that displays a meditation pause timer with start/skip options
struct ChatPauseBlock: View {
    @Environment(\.colorScheme) private var colorScheme
    let duration: TimeInterval
    let onComplete: () -> Void
    let onReset: (() -> Void)?
    let isFirstPause: Bool
    let isLastPause: Bool
    let scrollProxy: ScrollViewProxy?
    let messageId: PersistentIdentifier
    
    @State private var timeRemaining: TimeInterval
    @State private var timer: Timer?
    @State private var state: TimerState
    @State private var completedDuration: TimeInterval = 0
    @StateObject private var bellPlayer = BellPlayer()
    
    // System sound ID for transition
    private let pauseRenderSound: SystemSoundID = 1104  // Gentle chime for transitions
    
    enum TimerState {
        case ready
        case active
        case completed
    }
    
    // Helper function to play meditation sounds
    private func playSound(_ type: SoundType) {
        switch type {
        case .bell:
            print("🔔 Playing meditation bell")
            bellPlayer.playBell()
        case .transition:
            print("🔔 Playing transition sound")
            AudioServicesPlaySystemSound(pauseRenderSound)
        }
    }
    
    private enum SoundType {
        case bell
        case transition
    }
    
    init(duration: TimeInterval, state: TimerState = .ready, isFirstPause: Bool = false, isLastPause: Bool = false, onComplete: @escaping () -> Void, onReset: (() -> Void)? = nil, scrollProxy: ScrollViewProxy?, messageId: PersistentIdentifier) {
        print("🎯 Initializing ChatPauseBlock - First: \(isFirstPause), Last: \(isLastPause)")
        self.duration = duration
        self.onComplete = onComplete
        self.onReset = onReset
        self.isFirstPause = isFirstPause
        self.isLastPause = isLastPause
        self.scrollProxy = scrollProxy
        self.messageId = messageId
        self._timeRemaining = State(initialValue: duration)
        self._state = State(initialValue: state)
        
        // Play transition sound if this is a subsequent pause that auto-starts
        if !isFirstPause && state == .ready {
            print("🔄 Auto-start sound for subsequent pause")
            AudioServicesPlaySystemSound(pauseRenderSound)
        }
    }
    
    private var formattedTime: String {
        let minutes = Int(timeRemaining) / 60
        let seconds = Int(timeRemaining) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            switch state {
            case .ready:
                // Start button - only show for first pause
                if isFirstPause {
                    Button {
                        print("🎬 Starting first meditation pause")
                        withAnimation(.spring(duration: 0.3)) {
                            state = .active
                            startTimer()
                            playSound(.bell)
                            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .stroke(
                                    Color.gray.opacity(colorScheme == .dark ? 0.2 : 0.1),
                                    style: StrokeStyle(
                                        lineWidth: 3,
                                        lineCap: .round
                                    )
                                )
                            
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 44))
                                .foregroundStyle(.accent)
                        }
                        .frame(width: 160, height: 160)
                    }
                    .buttonStyle(.plain)
                } else {
                    // Auto-start for subsequent pauses
                    Color.clear
                        .onAppear {
                            print("🔄 Auto-starting subsequent pause")
                            withAnimation(.spring(duration: 0.3)) {
                                state = .active
                                startTimer()
                                playSound(.transition)
                                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                            }
                        }
                }
                
            case .active:
                // Interactive timer circle
                CircularTimer(
                    timeRemaining: timeRemaining,
                    duration: duration,
                    isFirstOrLastPause: isFirstPause || isLastPause,
                    onTap: {
                        completedDuration = duration - timeRemaining
                        completeTimer()
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    }
                )
                .padding(.vertical, 24)
                .transition(.opacity.combined(with: .scale(scale: 0.95)).animation(.easeInOut(duration: 0.3)))
                .onAppear {
                    // Ensure pause block is fully visible with a small delay to account for rendering
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        if let proxy = scrollProxy {
                            withAnimation(.spring(duration: 0.3)) {
                                proxy.scrollTo(messageId, anchor: .bottom)
                            }
                        }
                    }
                }
                
            case .completed:
                // Success state with duration and reset option
                HStack(alignment: .center, spacing: 0) {
                    if let onReset {
                        // Combined success indicator and duration
                        Button {
                            withAnimation {
                                timeRemaining = duration
                                state = .ready
                                onReset()
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .medium))
                                
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.system(size: 12, weight: .light))
                            }
                            .foregroundStyle(.secondary.opacity(0.8))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.secondary.opacity(0.08))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Spacer(minLength: 0)
                }
                .frame(height: 36)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(colorScheme == .dark ? Color(.black) : Color(.white))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .onDisappear {
            print("👋 ChatPauseBlock disappearing")
            timer?.invalidate()
            timer = nil
        }
    }
    
    private func startTimer() {
        print("⏱️ Starting timer for \(duration) seconds")
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 0.1
            } else {
                completedDuration = duration
                completeTimer()
            }
        }
    }
    
    private func completeTimer() {
        print("✅ Completing timer")
        timer?.invalidate()
        timer = nil
        withAnimation(.spring(duration: 0.3)) {
            state = .completed
        }
        
        // Fade out any playing bell sound
        bellPlayer.fadeOutAndStop()
        
        // Play completion bell for last pause
        if isLastPause {
            print("🔔 Playing final meditation bell")
            playSound(.bell)
        }
        
        // Soft success haptic when timer completes
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        
        // Small delay to show completion state before continuing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            onComplete()
        }
    }
} 