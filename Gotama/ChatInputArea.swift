import SwiftUI
import Speech
import CoreHaptics
import UIKit

struct ChatInputArea: View {
    @Binding var messageText: String
    @Binding var isLoading: Bool
    @Binding var isRecording: Bool
    @Binding var errorMessage: String?
    @Binding var viewOpacity: Double
    @Binding var isTextFromRecognition: Bool
    @FocusState private var isFocused: Bool
    @Environment(\.colorScheme) private var colorScheme
    
    // Change to optional to track initialization
    @State private var feedbackGenerator: UINotificationFeedbackGenerator?
    @State private var hapticEngine: CHHapticEngine?
    
    let onSendMessage: () -> Void
    let onStopGeneration: () -> Void
    let onStartDictation: () -> Void
    let onStopDictation: () -> Void
    let inputPlaceholder: String
    let showInput: Bool
    
    init(messageText: Binding<String>,
         isLoading: Binding<Bool>,
         isRecording: Binding<Bool>,
         errorMessage: Binding<String?>,
         viewOpacity: Binding<Double>,
         isTextFromRecognition: Binding<Bool>,
         inputPlaceholder: String = "Chat with Gotama",
         showInput: Bool = true,
         onSendMessage: @escaping () -> Void,
         onStopGeneration: @escaping () -> Void,
         onStartDictation: @escaping () -> Void,
         onStopDictation: @escaping () -> Void) {
        _messageText = messageText
        _isLoading = isLoading
        _isRecording = isRecording
        _errorMessage = errorMessage
        _viewOpacity = viewOpacity
        _isTextFromRecognition = isTextFromRecognition
        self.inputPlaceholder = inputPlaceholder
        self.showInput = showInput
        self.onSendMessage = onSendMessage
        self.onStopGeneration = onStopGeneration
        self.onStartDictation = onStartDictation
        self.onStopDictation = onStopDictation
    }
    
    private func prepareHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        
        do {
            hapticEngine = try CHHapticEngine()
            try hapticEngine?.start()
            
            // Keep engine alive
            hapticEngine?.resetHandler = { [weak hapticEngine] in
                print("🫳 Haptic engine needs reset")
                do {
                    try hapticEngine?.start()
                } catch {
                    print("🫳 Failed to restart haptic engine: \(error)")
                }
            }
            
            hapticEngine?.stoppedHandler = { reason in
                print("🫳 Haptic engine stopped: \(reason)")
            }
            
            // print("🫳 Haptic engine initialized successfully")
        } catch {
            print("🫳 Failed to create haptic engine: \(error)")
        }
    }
    
    private func playHapticFeedback() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics,
              let engine = hapticEngine else { return }
        
        do {
            let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0)
            let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
            let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: 0)
            
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
            print("🫳 Haptic feedback played successfully")
        } catch {
            print("🫳 Failed to play haptic: \(error)")
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Wrap TextField and button in a container
                HStack(spacing: 0) {
                    TextField(inputPlaceholder,
                             text: $messageText, axis: .vertical)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .focused($isFocused)
                        .disabled(isLoading)
                        .opacity(showInput ? 1 : 0)
                        .foregroundColor(isRecording ? .white : (messageText.isEmpty ? (colorScheme == .dark ? .white : .gray) : .primary))
                        .textFieldStyle(.plain)
                        .onChange(of: messageText) { oldValue, newValue in
                            print("💬 Message text changed: '\(oldValue)' -> '\(newValue)'")
                            print("🎤 Recording state: \(isRecording), isTextFromRecognition: \(isTextFromRecognition)")
                            
                            // Only stop dictation if text was manually changed (not from recognition)
                            if isRecording && !isTextFromRecognition {
                                // Add a small delay to ensure we don't stop dictation prematurely
                                Task { @MainActor in
                                    try? await Task.sleep(for: .nanoseconds(100_000_000)) // 100ms delay
                                    // Double check if we're still recording and it wasn't from recognition
                                    if isRecording && !isTextFromRecognition {
                                        onStopDictation()
                                    }
                                }
                            }
                        }
                    
                    Button {
                        if isLoading {
                            onStopGeneration()
                        } else if isRecording {
                            onStopDictation()
                        } else if messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            playHapticFeedback()
                            onStartDictation()
                        } else {
                            onSendMessage()
                        }
                    } label: {
                        Image(systemName: isLoading ? "stop.circle.fill" :
                              (isRecording ? "mic.fill" : 
                               (messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "mic" : "arrow.up.circle.fill")))
                            .font(.title2)
                            .foregroundColor(isLoading ? Color(white: 0.6) : (isRecording ? .white : .accent))
                            .symbolEffect(.bounce, value: isRecording)
                            .modifier(PulseEffect(isActive: isRecording))
                    }
                    .padding(.horizontal, 12)
                }
                .contentShape(Rectangle())
                .simultaneousGesture(
                    TapGesture()
                        .onEnded { _ in
                            print("👆 Input area tapped, current focus state: \(isFocused)")
                            guard !isFocused else { return }
                            Task { @MainActor in
                                try? await Task.sleep(for: .nanoseconds(1))  // Minimal delay to ensure view is ready
                                print("⌨️ Setting focus after tap")
                                withAnimation(.easeOut(duration: 0.2)) {
                                    isFocused = true
                                }
                            }
                        }
                )
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background {
                ZStack {
                    //   layer - always opaque
                    VStack(spacing: 0) {
                        Group {
                            colorScheme == .dark ? Color(white: 0.23) : Color(.systemGray4)
                        }
                        .clipShape(UnevenRoundedRectangle(cornerRadii: 
                            .init(topLeading: 36, bottomLeading: 0, bottomTrailing: 0, topTrailing: 36)))
                        
                        Group {
                            colorScheme == .dark ? Color(white: 0.23) : Color(.systemGray4)
                        }
                        .frame(maxHeight: .infinity)
                        .edgesIgnoringSafeArea(.bottom)
                    }
                    
                    // Accent color layer when recording
                    if isRecording {
                        VStack(spacing: 0) {
                            Color.accent
                                .opacity(0.8)
                                .clipShape(UnevenRoundedRectangle(cornerRadii: 
                                    .init(topLeading: 36, bottomLeading: 0, bottomTrailing: 0, topTrailing: 36)))
                            
                            Color.accent
                                .opacity(0.8)
                                .frame(maxHeight: .infinity)
                                .edgesIgnoringSafeArea(.bottom)
                        }
                        .transition(.opacity)
                    }
                }
                .onChange(of: isRecording) { wasRecording, isNowRecording in
                    print("🎙️ Recording state changed: \(wasRecording) -> \(isNowRecording)")
                    // Prepare generator for next use when recording stops
                    if !isNowRecording {
                        print("🫳 Preparing haptic for next use")
                        feedbackGenerator?.prepare()
                    }
                }
            }
            .animation(.easeOut(duration: 0.2), value: showInput)
        }
        .onAppear {
            feedbackGenerator = UINotificationFeedbackGenerator()
            feedbackGenerator?.prepare()
            // print("🫳 Haptic generator initialized and prepared")
            prepareHaptics()
        }
    }
}

#Preview {
    ChatInputArea(
        messageText: .constant(""),
        isLoading: .constant(false),
        isRecording: .constant(false),
        errorMessage: .constant(nil),
        viewOpacity: .constant(1.0),
        isTextFromRecognition: .constant(false),
        onSendMessage: {},
        onStopGeneration: {},
        onStartDictation: {},
        onStopDictation: {}
    )
} 