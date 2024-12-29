import SwiftUI
import Speech

struct ChatInputArea: View {
    @Binding var messageText: String
    @Binding var isLoading: Bool
    @Binding var isRecording: Bool
    @Binding var errorMessage: String?
    @Binding var viewOpacity: Double
    @FocusState private var isFocused: Bool
    @Environment(\.colorScheme) private var colorScheme
    
    let onSendMessage: () -> Void
    let onStopGeneration: () -> Void
    let onStartDictation: () -> Void
    let onStopDictation: () -> Void
    let inputPlaceholder: String
    let showInput: Bool
    
    @State private var isTextFromRecognition = false
    
    init(messageText: Binding<String>,
         isLoading: Binding<Bool>,
         isRecording: Binding<Bool>,
         errorMessage: Binding<String?>,
         viewOpacity: Binding<Double>,
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
        self.inputPlaceholder = inputPlaceholder
        self.showInput = showInput
        self.onSendMessage = onSendMessage
        self.onStopGeneration = onStopGeneration
        self.onStartDictation = onStartDictation
        self.onStopDictation = onStopDictation
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
                        .foregroundColor(isRecording ? .white : (messageText.isEmpty ? (colorScheme == .dark ? .secondary : .primary.opacity(0.9)) : .primary))
                        .textFieldStyle(.plain)
                        .onChange(of: messageText) { oldValue, newValue in
                            print("💬 Message text changed: '\(oldValue)' -> '\(newValue)'")
                            print("🎤 Recording state: \(isRecording), isTextFromRecognition: \(isTextFromRecognition)")
                            if isRecording && !isTextFromRecognition {
                                onStopDictation()
                            }
                        }
                    
                    Button {
                        if isLoading {
                            onStopGeneration()
                        } else if isRecording {
                            onStopDictation()
                        } else if messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
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
                            .init(topLeading: 16, bottomLeading: 0, bottomTrailing: 0, topTrailing: 16)))
                        
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
                                    .init(topLeading: 16, bottomLeading: 0, bottomTrailing: 0, topTrailing: 16)))
                            
                            Color.accent
                                .opacity(0.8)
                                .frame(maxHeight: .infinity)
                                .edgesIgnoringSafeArea(.bottom)
                        }
                        .transition(.opacity)
                    }
                }
                .onChange(of: isRecording) { wasRecording, isNowRecording in
                    // print("🎙️ Recording state changed: \(wasRecording) -> \(isNowRecording)")
                }
            }
            .opacity(viewOpacity)
            .animation(.easeOut(duration: 0.2), value: viewOpacity)
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
        onSendMessage: {},
        onStopGeneration: {},
        onStartDictation: {},
        onStopDictation: {}
    )
} 