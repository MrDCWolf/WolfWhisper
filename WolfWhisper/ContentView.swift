import SwiftUI

struct ContentView: View {
    @State private var apiKey: String = ""
    @StateObject private var appState = AppStateModel()
    
    // Create services 
    private let keychainService = KeychainService.shared
    @State private var audioService: AudioService?
    
    var body: some View {
        VStack(spacing: 20) {
            Text("WolfWhisper")
                .font(.title)
                .fontWeight(.bold)
            
            Text("AI-Powered Voice Dictation")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Divider()
            
            // API Key Section
            VStack(alignment: .leading, spacing: 10) {
                Text("OpenAI API Key")
                    .font(.headline)
                
                SecureField("Enter your OpenAI API key", text: $apiKey)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Button("Save API Key") {
                    _ = keychainService.saveApiKey(apiKey)
                }
                .disabled(apiKey.isEmpty)
            }
            
            Divider()
            
            // Recording Section
            VStack(spacing: 15) {
                // Main Action Button
                Button(action: {
                    toggleRecording()
                }) {
                    // Button appearance changes based on state
                    ZStack {
                        Circle()
                            .foregroundColor(recordButtonColor())
                            .frame(width: 100, height: 100)
                        
                        Image(systemName: recordButtonIcon())
                            .font(.system(size: 40))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(PlainButtonStyle()) // Removes default button styling

                // Status Text
                Text(appState.statusText)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
            
            VStack {
                Text("Click the microphone to start recording")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(minWidth: 400, minHeight: 300)
        .onAppear {
            // Initialize audioService with the correct appState instance
            if audioService == nil {
                audioService = AudioService(
                    appState: appState, 
                    transcriptionService: TranscriptionService(keychainService: keychainService)
                )
            }
            
            Task {
                self.apiKey = await MainActor.run {
                    keychainService.loadApiKey()
                } ?? ""
            }
        }
    }
    
    private func toggleRecording() {
        guard let audioService = audioService else { return }
        
        if appState.currentState == .recording {
            audioService.stopRecording()
        } else {
            audioService.startRecording()
        }
    }
    
    private func recordButtonColor() -> Color {
        switch appState.currentState {
        case .idle:
            return .blue
        case .recording:
            return .red
        case .transcribing:
            return .orange
        }
    }
    
    private func recordButtonIcon() -> String {
        switch appState.currentState {
        case .idle:
            return "mic.circle.fill"
        case .recording:
            return "stop.circle.fill"
        case .transcribing:
            return "waveform.circle.fill"
        }
    }
}

#Preview {
    ContentView()
} 