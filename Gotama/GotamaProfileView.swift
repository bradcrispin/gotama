import SwiftUI
import SwiftData

struct GotamaProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    // Track the profile directly
    @State private var profile: GotamaProfile?
    @State private var model: String = GotamaProfile.defaultModel
    @State private var systemPrompt: String = GotamaProfile.defaultSystemPrompt
    @State private var hasLoaded = false
    
    // Information inclusion controls
    @State private var includeGoal: Bool = true
    @State private var includeAboutMe: Bool = true
    @State private var includeJournal: Bool = true
    
    // Settings query to check tool availability
    @Query private var settings: [Settings]
    
    private let haptics = UIImpactFeedbackGenerator(style: .medium)
    private let softHaptics = UIImpactFeedbackGenerator(style: .soft)
    private let maxSystemPromptLength = 2000
    
    // Model options with display names and descriptions
    private struct ModelOption: Identifiable {
        let id = UUID()
        let apiName: String
        let displayName: String
        let description: String
    }
    
    private let modelOptions = [
        ModelOption(
            apiName: "claude-3-5-sonnet-20241022",
            displayName: "Claude Sonnet 3.6",
            description: "Most intelligent model"
        ),
        ModelOption(
            apiName: "claude-3-5-haiku-latest",
            displayName: "Claude Haiku 3.5",
            description: "Best for daily use"
        )
    ]
    
    var body: some View {
        NavigationStack {
            Form {
                if hasLoaded {
                    Section {
                        ForEach(modelOptions) { option in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(option.displayName)
                                        .font(.body)
                                    Text(option.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if model == option.apiName {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                softHaptics.impactOccurred()
                                model = option.apiName
                            }
                        }
                    } header: {
                        Text("Model")
                    }

                    if let currentSettings = settings.first {
                        let hasNoContext = currentSettings.goal.isEmpty && 
                                         currentSettings.aboutMe.isEmpty && 
                                         !currentSettings.journalEnabled
                        
                        Section {
                            if !currentSettings.goal.isEmpty {
                                Toggle("My goal", isOn: $includeGoal)
                            }
                            if !currentSettings.aboutMe.isEmpty {
                                Toggle("About me", isOn: $includeAboutMe)
                            }
                            if currentSettings.journalEnabled {
                                Toggle("Journal", isOn: $includeJournal)
                            }
                        } header: {
                            Text("Context")
                        } footer: {
                            if hasNoContext {
                                Text("Add to your profile or enable tools to give Gotama more context.")
                                    .foregroundColor(.secondary)
                            } else {
                                Text("Adjust the context for conversations.")
                            }
                        }
                    }
                    
                    Section {
                        TextEditor(text: $systemPrompt)
                            .frame(minHeight: 100)
                            .onChange(of: systemPrompt) {
                                if systemPrompt.count > maxSystemPromptLength {
                                    systemPrompt = String(systemPrompt.prefix(maxSystemPromptLength))
                                }
                            }
                    } header: {
                        HStack {
                            Text("System Prompt")
                            Spacer()
                            if systemPrompt != GotamaProfile.defaultSystemPrompt {
                                Button {
                                    softHaptics.impactOccurred()
                                    systemPrompt = GotamaProfile.defaultSystemPrompt
                                } label: {
                                    Image(systemName: "arrow.counterclockwise")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    } footer: {
                        Group {
                            if systemPrompt.count > Int(Double(maxSystemPromptLength) * 0.8) {
                                Text("Getting close to limit (\(systemPrompt.count)/\(maxSystemPromptLength) characters)")
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Gotama")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        softHaptics.impactOccurred()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if hasLoaded {
                        Button("Save") {
                            haptics.impactOccurred()
                            saveProfile()
                            dismiss()
                        }
                    }
                }
            }
            .task {
                await loadProfile()
            }
        }
    }
    
    @MainActor
    private func loadProfile() async {
        do {
            let loadedProfile = try GotamaProfile.getOrCreate(modelContext: modelContext)
            self.profile = loadedProfile
            self.model = loadedProfile.model
            self.systemPrompt = loadedProfile.systemPrompt
            self.includeGoal = loadedProfile.includeGoal
            self.includeAboutMe = loadedProfile.includeAboutMe
            self.includeJournal = loadedProfile.includeJournal
            self.hasLoaded = true
            print("✅ Loaded profile - Model: \(loadedProfile.model)")
        } catch {
            print("❌ Error loading profile: \(error)")
        }
    }
    
    @MainActor
    private func saveProfile() {
        print("💾 Saving Gotama profile...")
        print("Model: \(model)")
        print("System Prompt length: \(systemPrompt.count)")
        print("Include Goal: \(includeGoal)")
        print("Include About Me: \(includeAboutMe)")
        print("Include Journal: \(includeJournal)")
        
        do {
            let profileToUpdate = try GotamaProfile.getOrCreate(modelContext: modelContext)
            profileToUpdate.model = model
            profileToUpdate.systemPrompt = systemPrompt
            profileToUpdate.includeGoal = includeGoal
            profileToUpdate.includeAboutMe = includeAboutMe
            profileToUpdate.includeJournal = includeJournal
            try modelContext.save()
            print("✅ Updated profile")
        } catch {
            print("❌ Error saving profile: \(error)")
        }
    }
} 