import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [Settings]
    @State private var apiKey: String = ""
    @State private var isApiKeyVisible = false
    @State private var firstName: String = ""
    @FocusState private var isApiKeyFocused: Bool
    let focusApiKey: Bool
    var onSaved: (() -> Void)?
    
    private let haptics = UIImpactFeedbackGenerator(style: .medium)
    private let softHaptics = UIImpactFeedbackGenerator(style: .soft)
    
    init(focusApiKey: Bool = false, onSaved: (() -> Void)? = nil) {
        self.focusApiKey = focusApiKey
        self.onSaved = onSaved
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("First Name", text: $firstName)
                } header: {
                    Text("Your Name")
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
        
        if let existingSettings = settings.first {
            print("📝 Updating existing settings")
            existingSettings.anthropicApiKey = apiKey
            existingSettings.firstName = firstName
        } else {
            print("✨ Creating new settings")
            let newSettings = Settings(firstName: firstName, anthropicApiKey: apiKey)
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