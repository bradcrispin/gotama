import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [Settings]
    @State private var apiKey: String = ""
    @State private var isApiKeyVisible = false
    @State private var firstName: String = ""
    
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
                        } else {
                            SecureField("API Key", text: $apiKey)
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
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveSettings()
                        dismiss()
                    }
                }
            }
            .onAppear {
                if let existingSettings = settings.first {
                    apiKey = existingSettings.anthropicApiKey
                    firstName = existingSettings.firstName
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
            
            // Configure AnthropicClient with new API key
            Task {
                let client = AnthropicClient()
                await client.configure(with: apiKey)
                print("🔄 Configured AnthropicClient with new API key")
            }
        } catch {
            print("❌ Error saving settings: \(error)")
        }
    }
} 