import SwiftUI
import Speech
import AVFoundation

/// A class that manages speech recognition functionality for the chat interface.
/// Handles microphone permissions, speech recognition, and audio session management.
///
/// Features:
/// - Microphone permission handling
/// - Speech recognition permission handling
/// - Real-time transcription
/// - Error handling and reporting
///
/// Usage:
/// ```swift
/// let handler = ChatDictationHandler()
/// handler.startDictation { result in
///     switch result {
///     case .success(let text):
///         messageText = text
///     case .failure(let error):
///         errorMessage = error.localizedDescription
///     }
/// }
/// ```
@MainActor
class ChatDictationHandler: ObservableObject {
    // MARK: - Published Properties
    /// Whether speech recognition is currently active
    @Published private(set) var isRecording = false
    /// Current error message, if any
    @Published private(set) var errorMessage: String?
    
    // MARK: - Private Properties
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    
    // MARK: - Initialization
    init() {
        speechRecognizer = SFSpeechRecognizer()
    }
    
    // MARK: - Public Methods
    /// Starts the dictation process
    /// - Parameter onTranscription: Callback that receives transcribed text
    func startDictation(onTranscription: @escaping (String) -> Void) {
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            errorMessage = "Speech recognition is not available at this time"
            return
        }
        
        // First check microphone permission
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission { [weak self] granted in
                if !granted {
                    self?.errorMessage = "Tap here to enable microphone access in Settings"
                    return
                }
                self?.checkSpeechRecognitionPermission(onTranscription: onTranscription)
            }
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
                if !granted {
                    self?.errorMessage = "Tap here to enable microphone access in Settings"
                    return
                }
                self?.checkSpeechRecognitionPermission(onTranscription: onTranscription)
            }
        }
    }
    
    /// Stops the current dictation session
    func stopDictation() {
        // Cancel recognition task first
        recognitionTask?.finish()
        recognitionTask = nil
        
        // End audio request
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        // Stop audio engine last
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        isRecording = false
    }
    
    // MARK: - Private Methods
    private func checkSpeechRecognitionPermission(onTranscription: @escaping (String) -> Void) {
        SFSpeechRecognizer.requestAuthorization { [weak self] authStatus in
            Task { @MainActor in
                switch authStatus {
                case .authorized:
                    if self?.isRecording == true {
                        self?.stopDictation()
                    } else {
                        do {
                            try await self?.startRecording(onTranscription: onTranscription)
                        } catch {
                            self?.errorMessage = "Failed to start recording: \(error.localizedDescription)"
                            print("Failed to start recording: \(error)")
                        }
                    }
                case .denied:
                    self?.errorMessage = "Tap here to enable speech recognition in Settings"
                case .restricted:
                    self?.errorMessage = "Speech recognition is restricted on this device"
                case .notDetermined:
                    self?.errorMessage = "Speech recognition not yet authorized"
                @unknown default:
                    self?.errorMessage = "Speech recognition not available"
                }
            }
        }
    }
    
    private func startRecording(onTranscription: @escaping (String) -> Void) async throws {
        // Cancel existing task and request
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw NSError(domain: "SpeechRecognition", code: -1, 
                         userInfo: [NSLocalizedDescriptionKey: "Unable to create recognition request"])
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        // For on-device recognition
        if #available(iOS 13, *) {
            recognitionRequest.requiresOnDeviceRecognition = true
        }
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                let transcribedText = result.bestTranscription.formattedString
                
                // Only update if the transcription has actual content
                if !transcribedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    // print("🎤 Speech recognition update: \(transcribedText)")
                    onTranscription(transcribedText)
                } else {
                    print("🎤 Ignoring empty transcription")
                }
            }
            
            if error != nil || (result?.isFinal ?? false) {
                // print("🎤 Speech recognition ended: \(error?.localizedDescription ?? "Final result")")
                self.stopDictation()
            }
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        
        isRecording = true
    }
}

// MARK: - Error Types
extension ChatDictationHandler {
    enum DictationError: LocalizedError {
        case microphonePermissionDenied
        case speechRecognitionPermissionDenied
        case recognitionNotAvailable
        case recognitionFailed(Error)
        
        var errorDescription: String? {
            switch self {
            case .microphonePermissionDenied:
                return "Microphone access is required for dictation"
            case .speechRecognitionPermissionDenied:
                return "Speech recognition permission is required for dictation"
            case .recognitionNotAvailable:
                return "Speech recognition is not available at this time"
            case .recognitionFailed(let error):
                return "Recognition failed: \(error.localizedDescription)"
            }
        }
    }
} 