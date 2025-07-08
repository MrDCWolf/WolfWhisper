import SwiftUI
import AVFoundation
@preconcurrency import ApplicationServices

struct OnboardingView: View {
    @ObservedObject var appState: AppState
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack {
                switch appState.onboardingState {
                case .welcome:
                    WelcomeView(appState: appState)
                case .apiKeySetup:
                    APIKeySetupView(appState: appState)
                case .modelSelection:
                    ModelSelectionView(appState: appState)
                case .permissionsSetup:
                    PermissionsSetupView(appState: appState)
                case .hotkeySetup:
                    HotkeySetupView(appState: appState)
                case .completed:
                    EmptyView()
                }
            }
            .padding(40)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct WelcomeView: View {
    @ObservedObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 30) {
            // App Icon/Logo
            Image(systemName: "waveform")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            VStack(spacing: 16) {
                Text("Welcome to WolfWhisper")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("AI-Powered Voice Dictation")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 12) {
                FeatureRow(icon: "mic.fill", title: "High-Quality Transcription", description: "Powered by OpenAI's Whisper AI")
                FeatureRow(icon: "keyboard", title: "Global Hotkey Support", description: "Dictate anywhere on your Mac")
                FeatureRow(icon: "doc.on.clipboard", title: "Smart Clipboard", description: "Automatic text insertion")
                FeatureRow(icon: "gear", title: "Customizable Settings", description: "Tailor the experience to your needs")
            }
            
            Spacer()
            
            Button(action: {
                appState.onboardingState = .apiKeySetup
            }) {
                Text("Get Started")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .frame(maxWidth: 500)
        .frame(maxHeight: .infinity)
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

struct APIKeySetupView: View {
    @ObservedObject var appState: AppState
    @State private var apiKey: String = ""
    @State private var isValidating: Bool = false
    @State private var validationError: String?
    
    var body: some View {
        VStack(spacing: 30) {
            VStack(spacing: 16) {
                Image(systemName: "key.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("OpenAI API Key")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Enter your OpenAI API key to enable voice transcription")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 16) {
                SecureField("sk-...", text: $apiKey)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.system(.body, design: .monospaced))
                
                if let error = validationError {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
                
                Link("Get your API key from OpenAI", destination: URL(string: "https://platform.openai.com/api-keys")!)
                    .font(.caption)
            }
            
            Spacer()
            
            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    Button("Back") {
                        appState.onboardingState = .welcome
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    
                    Button(action: validateAndContinue) {
                        if isValidating {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Validating...")
                            }
                        } else {
                            Text("Continue")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(apiKey.isEmpty || isValidating)
                }
                
                // Add some bottom padding to ensure buttons are visible
                Spacer().frame(height: 20)
            }
        }
        .frame(maxWidth: 500)
        .onAppear {
            apiKey = appState.openAIAPIKey
        }
    }
    
    private func validateAndContinue() {
        isValidating = true
        validationError = nil
        
        // Basic validation
        guard apiKey.hasPrefix("sk-") && apiKey.count > 20 else {
            validationError = "Please enter a valid OpenAI API key"
            isValidating = false
            return
        }
        
        // Save the API key to settings but don't save to keychain until onboarding is complete
        appState.openAIAPIKey = apiKey
        
        // For now, skip actual API validation and continue
        // In production, you might want to make a test API call
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            isValidating = false
            appState.onboardingState = .modelSelection
        }
    }
}

struct ModelSelectionView: View {
    @ObservedObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 30) {
            VStack(spacing: 16) {
                Image(systemName: "gear.badge.checkmark")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Choose Model")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Select the Whisper model for transcription")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 12) {
                ForEach(TranscriptionProvider.openAI.models, id: \.self) { model in
                    ModelCard(
                        modelName: model,
                        isSelected: appState.selectedOpenAIModel == model,
                        onSelect: {
                            appState.selectedOpenAIModel = model
                        }
                    )
                }
            }
            
            Spacer()
            
            HStack(spacing: 16) {
                Button("Back") {
                    appState.onboardingState = .apiKeySetup
                }
                .buttonStyle(SecondaryButtonStyle())
                
                Button("Continue") {
                    Task {
                        await appState.saveSettings()
                    }
                    appState.onboardingState = .permissionsSetup
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .frame(maxWidth: 500)
    }
    

}

struct ModelCard: View {
    let modelName: String
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(modelName)
                    .font(.headline)
                Text(modelName == "whisper-1" ? "Default Model" : "A different model")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
                    .font(.title2)
            }
        }
        .padding()
        .background(isSelected ? Color.blue.opacity(0.1) : Color.secondary.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
        )
        .onTapGesture {
            onSelect()
        }
    }
}

struct PermissionsSetupView: View {
    @ObservedObject var appState: AppState
    @State private var hasMicPermission: Bool = false
    @State private var hasAccessibilityPermission: Bool = false
    
    var body: some View {
        VStack(spacing: 30) {
            VStack(spacing: 16) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Permissions Setup")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("WolfWhisper needs a few permissions to work properly")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 16) {
                PermissionRow(
                    icon: "mic.fill",
                    title: "Microphone Access",
                    description: "Required for voice recording",
                    status: hasMicPermission ? .granted : .pending,
                    action: requestMicPermission
                )
                
                PermissionRow(
                    icon: "keyboard",
                    title: "Accessibility Access",
                    description: "Required for global hotkey and text insertion",
                    status: hasAccessibilityPermission ? .granted : .pending,
                    action: requestAccessibilityPermission
                )
            }
            
            Spacer()
            
            HStack(spacing: 16) {
                Button("Back") {
                    appState.onboardingState = .modelSelection
                }
                .buttonStyle(SecondaryButtonStyle())
                
                Button("Continue") {
                    appState.onboardingState = .hotkeySetup
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!hasMicPermission)
            }
        }
        .frame(maxWidth: 500)
        .onAppear(perform: checkPermissions)
    }
    
    private func checkPermissions() {
        // Check microphone permission
        hasMicPermission = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        
        // Check accessibility permission
        hasAccessibilityPermission = AXIsProcessTrusted()
    }
    
    private func requestMicPermission() {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            DispatchQueue.main.async {
                self.hasMicPermission = granted
            }
        }
    }
    
    private func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        
        // This just opens the dialog, the user has to manually grant permission
        // We will re-check on appear
        DispatchQueue.main.async {
            self.hasAccessibilityPermission = trusted
        }
    }
}

struct PermissionRow: View {
    enum PermissionStatus {
        case pending, granted, denied
    }
    
    let icon: String
    let title: String
    let description: String
    let status: PermissionStatus
    let action: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: action) {
                switch status {
                case .pending:
                    Text("Grant")
                        .foregroundColor(.blue)
                case .granted:
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                case .denied:
                    Text("Retry")
                        .foregroundColor(.red)
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

struct HotkeySetupView: View {
    @ObservedObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 30) {
            VStack(spacing: 16) {
                Image(systemName: "command")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Setup Hotkey")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Choose a keyboard shortcut for global dictation")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            HotkeyRecorderField(
                hotkeyDisplay: $appState.hotkeyDisplay,
                hotkeyModifiers: $appState.hotkeyModifiers,
                hotkeyKey: $appState.hotkeyKey
            )
            
            Spacer()
            
            HStack(spacing: 16) {
                Button("Back") {
                    appState.onboardingState = .permissionsSetup
                }
                .buttonStyle(SecondaryButtonStyle())
                
                Button("Finish") {
                    appState.hasCompletedOnboarding = true
                    Task {
                        await appState.saveSettings()
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .frame(maxWidth: 500)
    }
}

// Custom button styles
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .frame(minWidth: 120, minHeight: 44)
            .background(Color.blue)
            .cornerRadius(12)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.blue)
            .frame(minWidth: 120, minHeight: 44)
            .background(Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.blue, lineWidth: 2)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
} 