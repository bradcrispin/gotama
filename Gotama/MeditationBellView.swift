import SwiftUI

/// A view that provides an elegant meditation timer experience with bell sounds
struct MeditationBellView: View {
    // MARK: - Environment & State
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var bellPlayer = BellPlayer()
    
    // Timer state
    @State private var selectedDuration: TimeInterval = 600 // 10 minutes default
    @State private var timeRemaining: TimeInterval = 600
    @State private var isActive = false
    @State private var timer: Timer?
    
    // Animation states
    @State private var showCompletion = false
    @State private var isTransitioning = false
    @State private var bellScale: CGFloat = 1.0
    
    // Time increment in seconds (5 minutes)
    private let timeIncrement: TimeInterval = 300
    
    // MARK: - Body
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                VStack(spacing: 0) {  // Remove default spacing
                    // Top section with fixed height
                    VStack(spacing: 0) {
                        Spacer()
                            .frame(height: geometry.size.height * 0.1)
                        
                        // Bell icon with volume state - only show when not meditating and at initial time
                        if timeRemaining == selectedDuration {
                            bellIcon
                                .frame(height: geometry.size.height * 0.15)
                                .onChange(of: bellPlayer.volumeState) { oldState, newState in
                                    if oldState != newState {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                            bellScale = 1.2
                                        }
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                                bellScale = 1.0
                                            }
                                        }
                                    }
                                }
                        } else {
                            Spacer()
                                .frame(height: geometry.size.height * 0.15)
                        }
                        
                        // Timer with increment/decrement buttons
                        HStack(spacing: 16) {  // Reduced spacing
                            if !isActive {
                                Button(action: decrementTime) {
                                    Image(systemName: "minus")
                                        .font(.system(size: 28))  // Slightly larger
                                        .foregroundStyle(Color.secondary.opacity(0.8))
                                }
                                .disabled(selectedDuration <= timeIncrement)
                                .opacity(selectedDuration <= timeIncrement ? 0.3 : 1)
                            }
                            
                            // Timer display
                            CircularTimer(
                                timeRemaining: timeRemaining,
                                duration: selectedDuration,
                                isFirstOrLastPause: false,
                                onTap: toggleTimer
                            )
                            .opacity(isActive ? 1 : 0.8)
                            .frame(height: geometry.size.height * 0.35)
                            
                            if !isActive {
                                Button(action: incrementTime) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 28))  // Slightly larger
                                        .foregroundStyle(Color.secondary.opacity(0.8))
                                }
                            }
                        }
                        .padding(.horizontal, 24)  // Reduced padding
                    }
                    .frame(height: geometry.size.height * 0.6)  // Fixed height for top section
                    
                    // Bottom section with controls
                    VStack(spacing: 0) {
                        // Controls centered
                        HStack {
                            Spacer()
                            controlButtons
                            Spacer()
                        }
                        .frame(height: geometry.size.height * 0.15)
                        
                        Spacer()
                    }
                }
                
                // Completion overlay
                if showCompletion {
                    completionView
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(uiColor: .systemBackground).opacity(0.98))
                        .transition(.opacity)
                }
            }
            .padding(.horizontal)
            .navigationTitle("Meditation Timer")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: selectedDuration) { _, newDuration in
                timeRemaining = newDuration
            }
            .animation(.easeInOut(duration: 0.3), value: isActive)
            .animation(.easeInOut(duration: 0.3), value: showCompletion)
        }
    }
    
    // MARK: - Views
    
    /// Bell icon with volume state indication
    private var bellIcon: some View {
        Image(systemName: bellPlayer.volumeState == .muted ? "bell.slash" : "bell")
            .font(.system(size: 28))
            .foregroundStyle(Color.accent.opacity(0.6))
            .symbolEffect(.bounce, options: .repeat(2), value: bellPlayer.volumeState)
            .scaleEffect(bellScale)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: bellScale)
    }
    
    /// Timer control buttons
    private var controlButtons: some View {
        ZStack {
            // Play/Pause button centered
            Button(action: toggleTimer) {
                Circle()
                    .fill(Color.accent.opacity(0.1))
                    .frame(width: 72, height: 72)  // Main button
                    .overlay(
                        Image(systemName: isActive ? "pause.fill" : "play.fill")
                            .font(.title2)
                            .foregroundColor(Color.accent)
                    )
            }
            
            // Reset button offset to the left - only show when paused and time remaining is less than selected
            if !isActive && timeRemaining < selectedDuration {
                HStack {
                    Button(action: resetTimer) {
                        Circle()
                            .fill(Color.gray.opacity(0.1))
                            .frame(width: 44, height: 44)  // Smaller than main button
                            .overlay(
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.title2)
                                    .foregroundColor(Color.primary.opacity(0.6))
                            )
                    }
                    .transition(.scale.combined(with: .opacity))
                    
                    Spacer()
                }
                .frame(width: 200)  // Fixed width to ensure consistent offset
            }
        }
        .frame(maxWidth: .infinity)  // Allow ZStack to take full width
        .animation(.easeInOut(duration: 0.2), value: isActive)
        .animation(.easeInOut(duration: 0.2), value: timeRemaining)
    }
    
    /// View shown when meditation is complete
    private var completionView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 44))
                .foregroundColor(Color.accent)
            
            Text("Meditation Complete")
                .font(.title3.weight(.medium))
                .foregroundColor(Color.primary.opacity(0.8))
            
            Button(action: resetTimer) {
                Text("Start Again")
                    .font(.headline)
                    .foregroundColor(Color.accent)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(Color.accent.opacity(0.1))
                    )
            }
        }
    }
    
    // MARK: - Computed Properties
    
    /// Returns the appropriate bell icon name based on volume state
    private var bellIconName: String {
        bellPlayer.volumeState == .muted ? "bell.slash.fill" : "bell.fill"
    }
    
    /// Returns the appropriate bell color based on volume state
    private var bellColor: Color {
        Color.accent.opacity(0.6)
    }
    
    /// Returns the appropriate message based on volume state
    private var bellStateMessage: String {
        ""  // No messages shown anymore
    }
    
    // MARK: - Methods
    
    /// Starts or pauses the meditation timer
    private func toggleTimer() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isActive.toggle()
        }
        
        if isActive {
            startTimer()
        } else {
            pauseTimer()
        }
    }
    
    /// Starts the meditation timer
    private func startTimer() {
        // Play initial bell
        bellPlayer.playBell()
        
        // Create and start timer
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                completeTimer()
            }
        }
    }
    
    /// Pauses the meditation timer
    private func pauseTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    /// Resets the meditation timer
    private func resetTimer() {
        // Stop the timer first
        pauseTimer()
        
        // Clean up audio before animation
        bellPlayer.fadeOutAndStop()
        
        // Update UI state with animation
        withAnimation(.easeInOut(duration: 0.3)) {
            isActive = false
            showCompletion = false
            timeRemaining = selectedDuration
        }
    }
    
    /// Handles timer completion
    private func completeTimer() {
        pauseTimer()
        withAnimation(.easeInOut(duration: 0.3)) {
            isActive = false
            showCompletion = true
        }
        
        // Play completion bell
        bellPlayer.playBell()
    }
    
    /// Increments the meditation duration
    private func incrementTime() {
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedDuration += timeIncrement
            timeRemaining = selectedDuration
        }
    }
    
    /// Decrements the meditation duration
    private func decrementTime() {
        guard selectedDuration > timeIncrement else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedDuration -= timeIncrement
            timeRemaining = selectedDuration
        }
    }
}

// MARK: - Previews
#Preview {
    NavigationStack {
        MeditationBellView()
    }
} 