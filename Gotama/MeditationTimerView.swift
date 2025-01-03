import SwiftUI
import MediaPlayer

// MARK: - UIImage Extension
fileprivate extension UIImage {
    func rotated(by radians: CGFloat) -> UIImage? {
        let rotatedSize = CGRect(origin: .zero, size: size)
            .applying(CGAffineTransform(rotationAngle: radians))
            .integral.size
        UIGraphicsBeginImageContext(rotatedSize)
        defer { UIGraphicsEndImageContext() }
        
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        context.translateBy(x: rotatedSize.width/2, y: rotatedSize.height/2)
        context.rotate(by: radians)
        draw(in: CGRect(x: -size.width/2, y: -size.height/2, width: size.width, height: size.height))
        
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}

/// A view that provides an elegant meditation timer experience with bell sounds
struct MeditationTimerView: View {
    // MARK: - Environment & State
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var bellPlayer = BellPlayer()
    
    // Timer state
    @State private var selectedDuration: TimeInterval = 600 // 10 minutes default
    @State private var timeRemaining: TimeInterval = 600
    @State private var isActive = false
    @State private var timer: Timer?
    @State private var backgroundDate: Date?
    
    // Animation states
    @State private var showCompletion = false
    @State private var isTransitioning = false
    @State private var bellScale: CGFloat = 1.0
    
    // Time increment in seconds (5 minutes)
    private let timeIncrement: TimeInterval = 300
    
    init() {
        setupRemoteCommandCenter()
    }
    
    private func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        // Remove any existing handlers
        commandCenter.playCommand.removeTarget(nil)
        commandCenter.pauseCommand.removeTarget(nil)
        commandCenter.togglePlayPauseCommand.removeTarget(nil)
        
        // Add command handlers
        commandCenter.playCommand.addTarget { [self] _ in
            if !isActive {
                toggleTimer()
                return .success
            }
            return .commandFailed
        }
        
        commandCenter.pauseCommand.addTarget { [self] _ in
            if isActive {
                toggleTimer()
                return .success
            }
            return .commandFailed
        }
        
        commandCenter.togglePlayPauseCommand.addTarget { [self] _ in
            toggleTimer()
            return .success
        }
    }
    
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
                if isActive {
                    updateNowPlaying()
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                switch newPhase {
                case .background:
                    handleBackground()
                case .active:
                    handleForeground()
                default:
                    break
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                handleBackground()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                handleForeground()
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
            setupNowPlaying()
        } else {
            pauseTimer()
            updateNowPlaying()
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
                updateNowPlaying()
            } else {
                completeTimer()
            }
        }
        
        // Add the timer to the common run loop modes
        RunLoop.current.add(timer!, forMode: .common)
        
        // Update background date
        backgroundDate = nil
    }
    
    /// Sets up Now Playing info for lock screen
    private func setupNowPlaying() {
        // Create canvas size and calculate symbol size (80% of canvas)
        let canvasSize = CGSize(width: 256, height: 256)
        let symbolSize = canvasSize.width * 0.82 // 82% of canvas width
        
        // Create artwork from SF Symbol with calculated size
        let config = UIImage.SymbolConfiguration(pointSize: symbolSize, weight: .regular)
        let backgroundColor: UIColor = colorScheme == .dark ? .systemBackground : .secondarySystemBackground
        
        // Create a context to draw the symbol with background
        UIGraphicsBeginImageContextWithOptions(canvasSize, false, 0)
        defer { UIGraphicsEndImageContext() }
        
        guard let context = UIGraphicsGetCurrentContext() else { return }
        
        // Draw background
        context.setFillColor(backgroundColor.cgColor)
        context.fill(CGRect(origin: .zero, size: canvasSize))
        
        // Draw symbol
        if let asterisk = UIImage(systemName: "asterisk", withConfiguration: config)?
            .withTintColor(.accent, renderingMode: .alwaysOriginal) {
            // Center the symbol in the canvas
            let rect = CGRect(
                x: (canvasSize.width - asterisk.size.width) / 2,
                y: (canvasSize.height - asterisk.size.height) / 2,
                width: asterisk.size.width,
                height: asterisk.size.height
            )
            
            // Apply rotation around the center
            context.translateBy(x: canvasSize.width/2, y: canvasSize.height/2)
            context.rotate(by: .pi/4) // 45 degrees
            context.translateBy(x: -canvasSize.width/2, y: -canvasSize.height/2)
            asterisk.draw(in: rect)
        }
        
        let image = UIGraphicsGetImageFromCurrentImageContext()
        
        var nowPlayingInfo: [String: Any] = [
            MPMediaItemPropertyTitle: "Meditation Timer",
            MPMediaItemPropertyArtist: "Gotama",
            MPNowPlayingInfoPropertyElapsedPlaybackTime: selectedDuration - timeRemaining,
            MPMediaItemPropertyPlaybackDuration: selectedDuration,
            MPNowPlayingInfoPropertyPlaybackRate: isActive ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: 1.0,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue
        ]
        
        // Add artwork if we created it
        if let image = image {
            nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        
        // Ensure we're the now playing app
        try? AVAudioSession.sharedInstance().setActive(true)
    }
    
    /// Updates Now Playing info on lock screen
    private func updateNowPlaying() {
        var nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = selectedDuration - timeRemaining
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isActive ? 1.0 : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    /// Handles app moving to background
    private func handleBackground() {
        backgroundDate = Date()
    }
    
    /// Handles app returning to foreground
    private func handleForeground() {
        guard isActive, let backgroundDate = backgroundDate else { return }
        
        let timeInBackground = Date().timeIntervalSince(backgroundDate)
        timeRemaining = max(0, timeRemaining - timeInBackground)
        
        if timeRemaining == 0 {
            completeTimer()
        }
        
        self.backgroundDate = nil
        updateNowPlaying()
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
        MeditationTimerView()
    }
} 