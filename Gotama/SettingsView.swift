import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [Settings]
    @State private var apiKey: String = ""
    @State private var isApiKeyVisible = false
    @State private var firstName: String = ""
    @State private var priorExperience: String = ""
    @State private var aboutMe: String = ""
    @State private var goal: String = ""
    @State private var journalEnabled: Bool = false
    @FocusState private var isApiKeyFocused: Bool
    let focusApiKey: Bool
    var onSaved: (() -> Void)?
    
    private let haptics = UIImpactFeedbackGenerator(style: .medium)
    private let softHaptics = UIImpactFeedbackGenerator(style: .soft)
    
    private let maxAboutMeLength = 500
    private let maxGoalLength = 200
    private let maxPriorExperienceLength = 300
    
    init(focusApiKey: Bool = false, onSaved: (() -> Void)? = nil) {
        self.focusApiKey = focusApiKey
        self.onSaved = onSaved
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("", text: $firstName)
                } header: {
                    Text("First name")
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
                    Text("My goal")
                } footer: {
                    Group {
                        if goal.count > Int(Double(maxGoalLength) * 0.8) {
                            Text("Getting close to limit (\(goal.count)/\(maxGoalLength) characters)")
                                .foregroundColor(.orange)
                        }
                    }
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
                    Text("About me")
                } footer: {
                    Group {
                        if aboutMe.count > Int(Double(maxAboutMeLength) * 0.8) {
                            Text("Getting close to limit (\(aboutMe.count)/\(maxAboutMeLength) characters)")
                                .foregroundColor(.orange)
                        }
                    }
                }
                
                Section {
                    Toggle("Journal", isOn: $journalEnabled)
                } header: {
                    Text("Tools")
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
                    Text("Get your API key from console.anthropic.com")
                }
            }
            .navigationTitle("Profile")
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
                    // priorExperience = existingSettings.priorExperience
                    aboutMe = existingSettings.aboutMe
                    goal = existingSettings.goal
                    journalEnabled = existingSettings.journalEnabled
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
        print("Prior Experience length: \(priorExperience.count)")
        print("About Me length: \(aboutMe.count)")
        print("Goal length: \(goal.count)")
        print("Journal: \(journalEnabled)")
        
        if let existingSettings = settings.first {
            print("📝 Updating existing settings")
            existingSettings.anthropicApiKey = apiKey
            existingSettings.firstName = firstName
            // existingSettings.priorExperience = priorExperience
            existingSettings.aboutMe = aboutMe
            existingSettings.goal = goal
            existingSettings.journalEnabled = journalEnabled
        } else {
            print("✨ Creating new settings")
            let newSettings = Settings(
                firstName: firstName,
                anthropicApiKey: apiKey,
                priorExperience: priorExperience,
                aboutMe: aboutMe,
                goal: goal,
                journalEnabled: journalEnabled
            )
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