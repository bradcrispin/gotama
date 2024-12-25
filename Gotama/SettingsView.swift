import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [Settings]
    @State private var apiKey: String = ""
    @State private var isApiKeyVisible = false
    @State private var firstName: String = ""
    @State private var aboutMe: String = ""
    @State private var goal: String = ""
    @FocusState private var isApiKeyFocused: Bool
    let focusApiKey: Bool
    var onSaved: (() -> Void)?
    
    private let haptics = UIImpactFeedbackGenerator(style: .medium)
    private let softHaptics = UIImpactFeedbackGenerator(style: .soft)
    
    private let maxAboutMeLength = 500
    private let maxGoalLength = 200
    
    init(focusApiKey: Bool = false, onSaved: (() -> Void)? = nil) {
        self.focusApiKey = focusApiKey
        self.onSaved = onSaved
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("First name", text: $firstName)
                } header: {
                    Text("What should I call you?")
                }

                Section {
                    TextEditor(text: $goal)
                        .frame(minHeight: 60)
                        .onChange(of: goal) {
                            if goal.count > maxGoalLength {
                                goal = String(goal.prefix(maxGoalLength))
                            }
                        }
                } header: {
                    Text("Do you have a goal?")
                } footer: {
                    Text("It can be skillful to have a goal (\(goal.count)/\(maxGoalLength) characters)")
                }
                
                Section {
                    TextEditor(text: $aboutMe)
                        .frame(minHeight: 100)
                        .onChange(of: aboutMe) {
                            if aboutMe.count > maxAboutMeLength {
                                aboutMe = String(aboutMe.prefix(maxAboutMeLength))
                            }
                        }
                } header: {
                    Text("Tell me about yourself")
                } footer: {
                    Text("I can help you achieve your goal (\(aboutMe.count)/\(maxAboutMeLength) characters)")
                }
                
                Section {
                    HStack {
                        if isApiKeyVisible {
                            TextField("API Key", text: $apiKey)
                                .focused($isApiKeyFocused)
                        } else {
                            SecureField("API Key", text: $apiKey)
                                .focused($isApiKeyFocused)
                        }
                        
                        Button {
                            isApiKeyVisible.toggle()
                        } label: {
                            Image(systemName: isApiKeyVisible ? "eye.slash" : "eye")
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Anthropic API Key")
                } footer: {
                    Text("Get your API key from anthropic.com")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        softHaptics.impactOccurred()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        haptics.impactOccurred()
                        saveSettings()
                        onSaved?()
                        dismiss()
                    }
                }
            }
            .onAppear {
                if let existingSettings = settings.first {
                    apiKey = existingSettings.anthropicApiKey
                    firstName = existingSettings.firstName
                    aboutMe = existingSettings.aboutMe
                    goal = existingSettings.goal
                }
                if focusApiKey {
                    isApiKeyFocused = true
                }
            }
        }
    }
    
    private func saveSettings() {
        print("💾 Saving settings...")
        print("API Key length: \(apiKey.count)")
        print("First Name: \(firstName)")
        print("About Me length: \(aboutMe.count)")
        print("Goal length: \(goal.count)")
        
        if let existingSettings = settings.first {
            print("📝 Updating existing settings")
            existingSettings.anthropicApiKey = apiKey
            existingSettings.firstName = firstName
            existingSettings.aboutMe = aboutMe
            existingSettings.goal = goal
        } else {
            print("✨ Creating new settings")
            let newSettings = Settings(firstName: firstName, anthropicApiKey: apiKey, aboutMe: aboutMe, goal: goal)
            modelContext.insert(newSettings)
        }
        
        // Try to save explicitly
        do {
            try modelContext.save()
            print("✅ Settings saved successfully")
            onSaved?()
        } catch {
            print("❌ Error saving settings: \(error)")
        }
    }
} 