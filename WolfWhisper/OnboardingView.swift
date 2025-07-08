import SwiftUI
import AVFoundation
@preconcurrency import ApplicationServices

struct OnboardingView: View {
    @ObservedObject var appState: AppStateModel
    
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
    @ObservedObject var appState: AppStateModel
    
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
    @ObservedObject var appState: AppStateModel
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
            apiKey = appState.settings.apiKey
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
        appState.settings.apiKey = apiKey
        
        // For now, skip actual API validation and continue
        // In production, you might want to make a test API call
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            isValidating = false
            appState.onboardingState = .modelSelection
        }
    }
}

struct ModelSelectionView: View {
    @ObservedObject var appState: AppStateModel
    
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
                ForEach(WhisperModel.allCases, id: \.self) { model in
                    ModelCard(
                        model: model,
                        isSelected: appState.settings.selectedModel == model,
                        onSelect: {
                            appState.settings.selectedModel = model
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
                    appState.settings.saveSettings()
                    appState.onboardingState = .permissionsSetup
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .frame(maxWidth: 500)
    }
    

}

struct ModelCard: View {
    let model: WhisperModel
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(model.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                }
            }
            .padding()
            .background(isSelected ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct PermissionsSetupView: View {
    @ObservedObject var appState: AppStateModel
    @State private var microphonePermission: AVAuthorizationStatus = .notDetermined
    @State private var accessibilityPermission: Bool = false
    
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
                    status: microphonePermission == .authorized ? .granted : .pending,
                    action: requestMicrophonePermission
                )
                
                PermissionRow(
                    icon: "keyboard",
                    title: "Accessibility Access",
                    description: "Required for global hotkey and text insertion",
                    status: accessibilityPermission ? .granted : .pending,
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
                .disabled(microphonePermission != .authorized)
            }
        }
        .frame(maxWidth: 500)
        .onAppear {
            checkPermissions()
        }
    }
    
    private func checkPermissions() {
        microphonePermission = AVCaptureDevice.authorizationStatus(for: .audio)
        // TODO: Check accessibility permission
    }
    
    private func requestMicrophonePermission() {
        Task {
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            await MainActor.run {
                microphonePermission = granted ? .authorized : .denied
            }
        }
    }
    
    private func requestAccessibilityPermission() {
        // First, make a request to trigger the app to appear in accessibility settings
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let _ = AXIsProcessTrustedWithOptions([promptKey: true] as CFDictionary)
        
        // Then open System Preferences to Accessibility settings
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
        
        // Update the permission status after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            checkPermissions()
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
    @ObservedObject var appState: AppStateModel
    @State private var isRecordingHotkey = false
    @State private var recordedModifiers = ""
    @State private var recordedKey = ""
    
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
            
            VStack(spacing: 20) {
                HStack {
                    Text("Current Hotkey:")
                        .font(.headline)
                    Spacer()
                    Text(appState.settings.hotkeyDisplay)
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                }
                
                VStack(spacing: 12) {
                    Button(action: {
                        if isRecordingHotkey {
                            stopRecording()
                        } else {
                            startRecording()
                        }
                    }) {
                        Text(isRecordingHotkey ? "Recording... Press ESC to cancel" : "Change Hotkey")
                            .foregroundColor(isRecordingHotkey ? .orange : .blue)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(isRecordingHotkey ? Color.orange.opacity(0.1) : Color.blue.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    if isRecordingHotkey {
                        VStack(spacing: 8) {
                            Text("Try these combinations:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            HStack(spacing: 12) {
                                ForEach(["⌘⇧D", "⌘⇧V", "⌘⇧T", "⌘⇧R"], id: \.self) { combo in
                                    Button(combo) {
                                        let parts = parseHotkeyCombo(combo)
                                        appState.settings.hotkeyModifiers = parts.modifiers
                                        appState.settings.hotkeyKey = parts.key
                                        appState.settings.hotkeyDisplay = combo
                                        stopRecording()
                                    }
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(4)
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                    }
                }
                
                Toggle("Enable Global Hotkey", isOn: $appState.settings.hotkeyEnabled)
                    .font(.headline)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            
            Spacer()
            
            HStack(spacing: 16) {
                Button("Back") {
                    appState.onboardingState = .permissionsSetup
                }
                .buttonStyle(SecondaryButtonStyle())
                
                Button("Complete Setup") {
                    // Now save everything including to keychain
                    appState.settings.saveSettings()
                    appState.completeOnboarding()
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .frame(maxWidth: 500)
    }
    
    private func startRecording() {
        isRecordingHotkey = true
        recordedModifiers = ""
        recordedKey = ""
    }
    
    private func stopRecording() {
        isRecordingHotkey = false
    }
    
    private func parseHotkeyCombo(_ combo: String) -> (modifiers: UInt, key: UInt16) {
        // Parse combinations like "⌘⇧D" into modifiers and key
        let keyChar = combo.last ?? "D"
        let modifierString = String(combo.dropLast())
        
        // Convert key character to key code
        let keyCode: UInt16
        switch keyChar.uppercased() {
        case "A": keyCode = 0x00
        case "B": keyCode = 0x0B
        case "C": keyCode = 0x08
        case "D": keyCode = 0x02
        case "E": keyCode = 0x0E
        case "F": keyCode = 0x03
        case "G": keyCode = 0x05
        case "H": keyCode = 0x04
        case "I": keyCode = 0x22
        case "J": keyCode = 0x26
        case "K": keyCode = 0x28
        case "L": keyCode = 0x25
        case "M": keyCode = 0x2E
        case "N": keyCode = 0x2D
        case "O": keyCode = 0x1F
        case "P": keyCode = 0x23
        case "Q": keyCode = 0x0C
        case "R": keyCode = 0x0F
        case "S": keyCode = 0x01
        case "T": keyCode = 0x11
        case "U": keyCode = 0x20
        case "V": keyCode = 0x09
        case "W": keyCode = 0x0D
        case "X": keyCode = 0x07
        case "Y": keyCode = 0x10
        case "Z": keyCode = 0x06
        default: keyCode = 0x02 // Default to 'D'
        }
        
        // Convert modifier symbols to flags
        var modifierFlags: UInt = 0
        if modifierString.contains("⌘") {
            modifierFlags |= NSEvent.ModifierFlags.command.rawValue
        }
        if modifierString.contains("⇧") {
            modifierFlags |= NSEvent.ModifierFlags.shift.rawValue
        }
        if modifierString.contains("⌥") {
            modifierFlags |= NSEvent.ModifierFlags.option.rawValue
        }
        if modifierString.contains("⌃") {
            modifierFlags |= NSEvent.ModifierFlags.control.rawValue
        }
        
        return (modifiers: modifierFlags, key: keyCode)
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