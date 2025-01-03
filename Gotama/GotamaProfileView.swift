import SwiftUI
import SwiftData

struct GotamaProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    // Track the profile directly
    @State private var profile: GotamaProfile?
    @State private var model: String = GotamaProfile.defaultModel
    @State private var hasLoaded = false
    @State private var selectedText = AncientText.none
    @State private var role: String = GotamaProfile.defaultRole
    
    // Information inclusion controls
    @State private var includeGoal: Bool = true
    @State private var includeAboutMe: Bool = true
    @State private var includeJournal: Bool = true
    
    // Settings query to check tool availability
    @Query private var settings: [Settings]
    
    private let haptics = UIImpactFeedbackGenerator(style: .medium)
    private let softHaptics = UIImpactFeedbackGenerator(style: .soft)
    
    // Model options with display names and descriptions
    private struct ModelOption: Identifiable {
        let id = UUID()
        let apiName: String
        let displayName: String
        let description: String
    }
    
    private struct RoleOption: Identifiable {
        let id = UUID()
        let name: String
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
    
    private let roleOptions = [
        RoleOption(
            name: "Teacher",
            displayName: "Teacher",
            description: "Gotama acts as your mindfulness guide"
        ),
        RoleOption(
            name: "Assistant",
            displayName: "Assistant",
            description: "Gotama helps with your normal chat tasks"
        )
    ]
    
    var body: some View {
        NavigationStack {
            Form {

                                
                Section {
                    ForEach(roleOptions) { option in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(option.displayName)
                                    .font(.body)
                                Text(option.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if role == option.name {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            softHaptics.impactOccurred()
                            role = option.name
                        }
                    }
                } header: {
                    Text("Role")
                }

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
                
                if hasLoaded {

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
                            Text("Add to your profile or enable tools to give Gotama more context")
                                .foregroundColor(.secondary)
                        } else {
                            Text("Give Gotama more context for conversations")
                        }
                    }
                }
                                        Section {
                        ForEach(AncientText.allCases) { text in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(text.rawValue)
                                        .font(.body)
                                    Text(text.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if selectedText == text {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                softHaptics.impactOccurred()
                                selectedText = text
                            }
                        }
                    } header: {
                        Text("Ancient Texts")
                    } footer: {
                        Text("Select an early Buddhist text for Gotama to reference in responses.")
                    }
                }
            }
            .navigationTitle("Gotama")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 3) {
                        Text("Gotama")
                            .fontWeight(.semibold)
                        Text(role == "Teacher" ? 
                             (selectedText == .none ? "Modern" : "Ancient") :
                             "Assistant")
                            .foregroundStyle(.gray.opacity(0.8))
                    }
                }
                
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
            self.role = loadedProfile.role
            self.includeGoal = loadedProfile.includeGoal
            self.includeAboutMe = loadedProfile.includeAboutMe
            self.includeJournal = loadedProfile.includeJournal
            self.selectedText = AncientText(rawValue: loadedProfile.selectedText) ?? .none
            self.hasLoaded = true
            print("✅ Loaded profile - Model: \(loadedProfile.model), Role: \(loadedProfile.role), Text: \(loadedProfile.selectedText)")
        } catch {
            print("❌ Error loading profile: \(error)")
        }
    }
    
    @MainActor
    private func saveProfile() {
        print("💾 Saving Gotama profile...")
        print("Model: \(model)")
        print("Role: \(role)")
        print("Include Goal: \(includeGoal)")
        print("Include About Me: \(includeAboutMe)")
        print("Include Journal: \(includeJournal)")
        print("Selected Text: \(selectedText.rawValue)")
        
        do {
            let profileToUpdate = try GotamaProfile.getOrCreate(modelContext: modelContext)
            profileToUpdate.model = model
            profileToUpdate.role = role
            profileToUpdate.includeGoal = includeGoal
            profileToUpdate.includeAboutMe = includeAboutMe
            profileToUpdate.includeJournal = includeJournal
            profileToUpdate.selectedText = selectedText.rawValue
            try modelContext.save()
            print("✅ Updated profile")
        } catch {
            print("❌ Error saving profile: \(error)")
        }
    }
} 