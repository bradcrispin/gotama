import AVFoundation
/// A custom bell sound player that creates a more meditation-appropriate sound
class BellPlayer: ObservableObject {
    private var audioEngine: AVAudioEngine
    private var playerNode: AVAudioPlayerNode
    private var timeEffect: AVAudioUnitTimePitch
    private var reverbEffect: AVAudioUnitReverb
    private var fadeTimer: Timer?
    private var audioFile: AVAudioFile?
    private var volumeObserver: NSKeyValueObservation?
    
    // Audio enhancement parameters
    private let bellDuration: TimeInterval = 30.0  // Total duration
    private let attackTime: TimeInterval = 0.05    // Quick initial strike
    private let peakTime: TimeInterval = 0.2      // Time to reach peak after attack
    private let initialDecayTime: TimeInterval = 2.0  // Initial decay phase
    private let longDecayTime: TimeInterval = 27.75   // Long, gentle decay phase
    private let updateInterval: TimeInterval = 0.05   // 50ms updates for smooth fade
    private let quickFadeOutDuration: TimeInterval = 2.0 // Duration for quick fade out when skipped
    
    init() {
        audioEngine = AVAudioEngine()
        playerNode = AVAudioPlayerNode()
        timeEffect = AVAudioUnitTimePitch()
        reverbEffect = AVAudioUnitReverb()
        
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
                
                // Connect nodes with the correct format
                audioEngine.connect(playerNode, to: timeEffect, format: format)
                audioEngine.connect(timeEffect, to: reverbEffect, format: format)
                audioEngine.connect(reverbEffect, to: audioEngine.mainMixerNode, format: format)
                
                // Configure effects for rich bell sound
                timeEffect.pitch = -300  // Slightly lower pitch for depth
                reverbEffect.loadFactoryPreset(.largeChamber)
                reverbEffect.wetDryMix = 70  // More reverb for longer sustain
                
                print("🔔 Audio file loaded successfully")
            } catch {
                print("❌ Failed to load audio file: \(error)")
            }
        } else {
            print("❌ Bell sound file not found")
        }
        
        // Start engine
        do {
            try audioEngine.start()
            print("🔔 Bell audio engine started")
            
            // Setup audio session
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            
            // Observe volume changes using AVAudioSession KVO
            volumeObserver = AVAudioSession.sharedInstance().observe(\.outputVolume) { [weak self] _, _ in
                self?.checkVolume()
            }
            
            // Initial volume check
            checkVolume()
            
        } catch {
            print("❌ Failed to start audio engine: \(error)")
        }
    }
    
    private func checkVolume() {
        let volume = AVAudioSession.sharedInstance().outputVolume
        if volume < 0.1 {
            print("⚠️ User volume is low (\(Int(volume * 100))%)")
        }
    }
    
    func playBell() {
        // Check volume before playing
        checkVolume()
        
        guard let audioFile = audioFile else {
            print("❌ No audio file loaded, falling back to system sound")
            AudioServicesPlaySystemSound(1013)
            return
        }
        
        do {
            let buffer = AVAudioPCMBuffer(pcmFormat: audioFile.processingFormat, frameCapacity: AVAudioFrameCount(audioFile.length))
            try audioFile.read(into: buffer!)
            
            // Reset player and timer
            playerNode.stop()
            fadeTimer?.invalidate()
            
            // Set initial volume to 0
            playerNode.volume = 0
            
            // Schedule buffer with looping for sustained sound
            playerNode.scheduleBuffer(buffer!, at: nil, options: .loops)
            
            // Start playing
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
        } catch {
            print("❌ Failed to play bell sound: \(error), falling back to system sound")
            AudioServicesPlaySystemSound(1013)
        }
    }
    
    /// Fades out the bell sound quickly and stops playback
    func fadeOutAndStop() {
        fadeTimer?.invalidate()
        
        let startVolume = playerNode.volume
        var elapsedTime: TimeInterval = 0
        
        fadeTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            elapsedTime += updateInterval
            
            if elapsedTime >= quickFadeOutDuration {
                self.playerNode.stop()
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
        volumeObserver?.invalidate()
        fadeTimer?.invalidate()
        audioEngine.stop()
        print("🔔 Bell audio engine stopped")
    }
}