import SwiftUI

struct ContentView: View {
    @Bindable var appState: AppStateModel
    
    @State private var apiKey: String = ""
    @State private var showSaved: Bool = false
    @State private var hotkey: String = "⌘⇧D" // Placeholder
    
    var body: some View {
        VStack(spacing: 16) {
            Text("WolfWhisper")
                .font(.headline)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Status: \(appState.statusText)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    Circle()
                        .fill(appState.currentState == .recording ? Color.red : Color.green)
                        .frame(width: 8, height: 8)
                    Text(appState.currentState == .recording ? "Recording..." : "Idle")
                        .font(.caption)
                }
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                Text("OpenAI API Key")
                    .font(.caption)
                    .fontWeight(.medium)
                
                SecureField("Enter your API key", text: $apiKey, onCommit: saveApiKey)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 250)
                
                HStack {
                    Button("Save") { saveApiKey() }
                        .controlSize(.small)
                    if showSaved {
                        Text("Saved!")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
                }
                
                Text("Your API key is stored securely in the macOS Keychain")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Global Hotkey")
                    .font(.caption)
                    .fontWeight(.medium)
                HStack {
                    Text(hotkey)
                        .padding(6)
                        .background(Color.gray.opacity(0.15))
                        .cornerRadius(6)
                    Text("(Configurable soon)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding()
        .frame(width: 280)
        .onAppear(perform: loadApiKey)
    }
    
    private func saveApiKey() {
        if KeychainService.shared.saveApiKey(apiKey) {
            showSaved = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                showSaved = false
            }
        }
    }
    
    private func loadApiKey() {
        if let key = KeychainService.shared.loadApiKey() {
            apiKey = key
        }
    }
}

#Preview {
    ContentView(appState: AppStateModel())
} 