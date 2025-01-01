import AVFoundation

/// A custom bell sound player that creates a more meditation-appropriate sound
class BellPlayer: ObservableObject {
    // MARK: - Published Properties
    @Published var volumeState: VolumeState = .normal
    
    // MARK: - Private Properties
    private var audioEngine: AVAudioEngine
    private var playerNode: AVAudioPlayerNode
    private var timeEffect: AVAudioUnitTimePitch
    private var reverbEffect: AVAudioUnitReverb
    private var fadeTimer: Timer?
    private var audioFile: AVAudioFile?
    private var audioBuffer: AVAudioPCMBuffer?
    private var volumeObserver: NSKeyValueObservation?
    private var audioSessionObserver: NSObjectProtocol?
    private var isEngineRunning = false
    
    // Audio enhancement parameters
    private let bellDuration: TimeInterval = 30.0  // Total duration
    private let attackTime: TimeInterval = 0.05    // Quick initial strike
    private let peakTime: TimeInterval = 0.2      // Time to reach peak after attack
    private let initialDecayTime: TimeInterval = 2.0  // Initial decay phase
    private let longDecayTime: TimeInterval = 27.75   // Long, gentle decay phase
    private let updateInterval: TimeInterval = 0.05   // 50ms updates for smooth fade
    private let quickFadeOutDuration: TimeInterval = 2.0 // Duration for quick fade out when skipped
    
    // Volume threshold
    private let mutedVolumeThreshold: Float = 0.01
    
    init() {
        audioEngine = AVAudioEngine()
        playerNode = AVAudioPlayerNode()
        timeEffect = AVAudioUnitTimePitch()
        reverbEffect = AVAudioUnitReverb()
        
        setupAudioSession()
        setupAudioEngine()
        setupNotifications()
    }
    
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            
            // Observe volume changes using AVAudioSession KVO
            volumeObserver = session.observe(\.outputVolume) { [weak self] _, _ in
                self?.checkVolume()
            }
            
            // Initial volume check
            checkVolume()
            
            print("🔔 Audio session setup complete")
        } catch {
            print("❌ Failed to setup audio session: \(error)")
        }
    }
    
    private func setupAudioEngine() {
        // Setup audio chain
        audioEngine.attach(playerNode)
        audioEngine.attach(timeEffect)
        audioEngine.attach(reverbEffect)
        
        // Load and prepare audio file
        if let url = Bundle.main.url(forResource: "bell-meditation-75335", withExtension: "mp3") {
            do {
                audioFile = try AVAudioFile(forReading: url)
                
                // Configure the audio engine format based on the file
                let format = audioFile!.processingFormat
                
                // Create and prepare the buffer once
                audioBuffer = AVAudioPCMBuffer(pcmFormat: format, 
                                             frameCapacity: AVAudioFrameCount(audioFile!.length))
                try audioFile!.read(into: audioBuffer!)
                
                // Connect nodes with the correct format
                audioEngine.connect(playerNode, to: timeEffect, format: format)
                audioEngine.connect(timeEffect, to: reverbEffect, format: format)
                audioEngine.connect(reverbEffect, to: audioEngine.mainMixerNode, format: format)
                
                // Configure effects for rich bell sound
                timeEffect.pitch = -300  // Slightly lower pitch for depth
                reverbEffect.loadFactoryPreset(.largeChamber)
                reverbEffect.wetDryMix = 70  // More reverb for longer sustain
                
                startEngine()
                print("🔔 Audio engine setup complete")
            } catch {
                print("❌ Failed to load audio file: \(error)")
            }
        } else {
            print("❌ Bell sound file not found")
        }
    }
    
    private func setupNotifications() {
        // Observe audio session interruptions
        audioSessionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let userInfo = notification.userInfo,
                  let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
                return
            }
            
            switch type {
            case .began:
                self.handleInterruptionBegan()
            case .ended:
                guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else { return }
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                self.handleInterruptionEnded(shouldResume: options.contains(.shouldResume))
            @unknown default:
                break
            }
        }
    }
    
    private func startEngine() {
        guard !isEngineRunning else { return }
        
        do {
            try audioEngine.start()
            isEngineRunning = true
            print("🔔 Audio engine started successfully")
        } catch {
            print("❌ Failed to start audio engine: \(error)")
            isEngineRunning = false
        }
    }
    
    private func stopEngine() {
        guard isEngineRunning else { return }
        audioEngine.stop()
        isEngineRunning = false
        print("🔔 Audio engine stopped")
    }
    
    private func handleInterruptionBegan() {
        fadeOutAndStop()
        stopEngine()
    }
    
    private func handleInterruptionEnded(shouldResume: Bool) {
        if shouldResume {
            startEngine()
        }
    }
    
    private func restartEngine() {
        stopEngine()
        setupAudioSession()
        setupAudioEngine()
    }
    
    private func cleanupAudioState() {
        // Stop any ongoing playback and timers
        fadeTimer?.invalidate()
        fadeTimer = nil
        
        // Stop and reset player node
        playerNode.stop()
        playerNode.reset()
        
        // Reset audio chain
        audioEngine.disconnectNodeOutput(playerNode)
        audioEngine.disconnectNodeOutput(timeEffect)
        audioEngine.disconnectNodeOutput(reverbEffect)
        
        // Ensure engine is in clean state
        stopEngine()
        
        // Reconnect audio chain and prepare buffer
        if let format = audioFile?.processingFormat {
            // Reconnect nodes
            audioEngine.connect(playerNode, to: timeEffect, format: format)
            audioEngine.connect(timeEffect, to: reverbEffect, format: format)
            audioEngine.connect(reverbEffect, to: audioEngine.mainMixerNode, format: format)
            
            // Recreate buffer if needed
            if audioBuffer == nil, let audioFile = audioFile {
                audioBuffer = AVAudioPCMBuffer(pcmFormat: format, 
                                             frameCapacity: AVAudioFrameCount(audioFile.length))
                try? audioFile.read(into: audioBuffer!)
            }
        }
        
        // Wait for audio system to stabilize before restarting
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.startEngine()
        }
    }
    
    func playBell() {
        // If engine isn't running or player is playing, clean up first
        if !isEngineRunning || playerNode.isPlaying {
            cleanupAudioState()
            // Retry after cleanup
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.playBellWithBuffer()
            }
            return
        }
        
        // Check volume before playing
        checkVolume()
        playBellWithBuffer()
    }
    
    private func playBellWithBuffer() {
        guard let buffer = audioBuffer, isEngineRunning else {
            print("❌ Audio engine not ready, falling back to system sound")
            AudioServicesPlaySystemSound(1013)
            return
        }
        
        // Ensure player node is ready
        playerNode.stop()
        playerNode.reset()
        
        // Schedule buffer with looping for sustained sound
        playerNode.scheduleBuffer(buffer, at: nil, options: .loops)
        
        // Start playing with initial volume 0
        playerNode.volume = 0
        
        // Ensure engine is running before playing
        if !audioEngine.isRunning {
            do {
                try audioEngine.start()
                isEngineRunning = true
            } catch {
                print("❌ Failed to start audio engine: \(error)")
                AudioServicesPlaySystemSound(1013)
                return
            }
        }
        
        playerNode.play()
        
        var elapsedTime: TimeInterval = 0
        fadeTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            elapsedTime += updateInterval
            
            if elapsedTime >= bellDuration {
                // End of sound
                self.fadeOutAndStop()
                timer.invalidate()
                return
            }
            
            // Calculate volume using a natural bell envelope
            let volume = self.calculateBellVolume(at: elapsedTime)
            
            // Apply volume with smooth easing
            self.playerNode.volume = volume
        }
        
        print("🔔 Playing meditation bell with 30-second envelope")
    }
    
    private func checkVolume() {
        let volume = AVAudioSession.sharedInstance().outputVolume
        
        // Update volume state on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let newState: VolumeState = volume < self.mutedVolumeThreshold ? .muted : .normal
            
            // Only update if state changed to avoid unnecessary publishes
            if self.volumeState != newState {
                self.volumeState = newState
            }
        }
    }
    
    /// Fades out the bell sound quickly and stops playback
    func fadeOutAndStop() {
        // Stop any existing fade timer
        fadeTimer?.invalidate()
        fadeTimer = nil
        
        let startVolume = playerNode.volume
        
        // If volume is already 0 or node isn't playing, stop immediately
        if startVolume == 0 || !playerNode.isPlaying {
            playerNode.stop()
            playerNode.reset()
            return
        }
        
        var elapsedTime: TimeInterval = 0
        fadeTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            elapsedTime += updateInterval
            
            if elapsedTime >= quickFadeOutDuration {
                self.playerNode.stop()
                self.playerNode.reset()
                timer.invalidate()
                return
            }
            
            // Linear fade out
            let progress = elapsedTime / quickFadeOutDuration
            let volume = startVolume * Float(1 - progress)
            self.playerNode.volume = volume
        }
    }
    
    /// Calculates the bell volume at a given time using a natural bell envelope curve
    private func calculateBellVolume(at time: TimeInterval) -> Float {
        if time < attackTime {
            // Initial strike (quick rise)
            return Float(time / attackTime)
        } else if time < attackTime + peakTime {
            // Peak resonance
            return 1.0
        } else if time < attackTime + peakTime + initialDecayTime {
            // Initial decay phase (faster)
            let decayProgress = (time - (attackTime + peakTime)) / initialDecayTime
            return 1.0 - Float(decayProgress) * 0.3 // Decay to 0.7
        } else {
            // Long decay phase (exponential decay)
            let decayProgress = (time - (attackTime + peakTime + initialDecayTime)) / longDecayTime
            let base: Float = 0.7 // Start from where initial decay ended
            let curve: Float = 3.0 // Adjust for smoother decay
            return base * pow(1 - Float(decayProgress), curve)
        }
    }
    
    deinit {
        fadeTimer?.invalidate()
        volumeObserver?.invalidate()
        
        if let observer = audioSessionObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        
        fadeOutAndStop()
        stopEngine()
        
        do {
            try AVAudioSession.sharedInstance().setActive(false)
            print("🔔 Audio session deactivated")
        } catch {
            print("❌ Failed to deactivate audio session: \(error)")
        }
    }
}

// MARK: - Volume State
extension BellPlayer {
    enum VolumeState: Equatable {
        case normal
        case muted
    }
}