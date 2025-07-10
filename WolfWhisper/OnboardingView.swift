import SwiftUI
import AVFoundation
@preconcurrency import ApplicationServices

struct OnboardingView: View {
    @ObservedObject var appState: AppStateModel
    
    var body: some View {
        ZStack {
            // Modern app background (gradient + glass morphism)
            GeometryReader { geometry in
                ZStack {
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.4, green: 0.6, blue: 0.8).opacity(0.3),
                            Color(red: 0.8, green: 0.6, blue: 0.4).opacity(0.3),
                            Color(red: 0.5, green: 0.8, blue: 0.6).opacity(0.3)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .opacity(0.8)
                }
                .ignoresSafeArea()
            }
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
            .padding(.horizontal, 28)
            .frame(minWidth: 455, idealWidth: 455, maxWidth: 455, minHeight: 510, idealHeight: 510, maxHeight: 510)
        }
    }
}

// Onboarding section container (unique name)
struct OnboardingSection<Content: View>: View {
    let title: String?
    let content: Content
    init(title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let title = title {
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
            }
            content
        }
        .padding(20)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 3)
    }
}

// Onboarding action button (unique name)
struct OnboardingActionButton: View {
    let title: String
    let style: ButtonStyle
    let action: () -> Void
    enum ButtonStyle {
        case primary, secondary, destructive
        var foregroundColor: Color {
            switch self {
            case .primary: return .white
            case .secondary: return .primary
            case .destructive: return .red
            }
        }
        var backgroundColor: Color {
            switch self {
            case .primary: return .blue
            case .secondary: return .clear
            case .destructive: return .clear
            }
        }
    }
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11.2, weight: .medium, design: .rounded))
                .foregroundStyle(style.foregroundColor)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .background(style.backgroundColor.opacity(0.9), in: RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(style.foregroundColor.opacity(0.2), lineWidth: 1)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct WelcomeView: View {
    @ObservedObject var appState: AppStateModel
    
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "waveform")
                .font(.system(size: 42))
                .foregroundColor(.blue)
            VStack(spacing: 16) {
                Text("Welcome to WolfWhisper")
                    .font(.system(size: 19.6, weight: .bold, design: .rounded))
                Text("AI-Powered Voice Dictation")
                    .font(.system(size: 11.2, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary)
            }
            VStack(spacing: 12) {
                FeatureRow(icon: "mic.fill", title: "High-Quality Transcription", description: "Powered by OpenAI's Whisper AI")
                FeatureRow(icon: "keyboard", title: "Global Hotkey Support", description: "Dictate anywhere on your Mac")
                FeatureRow(icon: "doc.on.clipboard", title: "Smart Clipboard", description: "Automatic text insertion")
                FeatureRow(icon: "gear", title: "Customizable Settings", description: "Tailor the experience to your needs")
            }
            Spacer()
            OnboardingActionButton(title: "Get Started", style: .primary) {
                appState.onboardingState = .apiKeySetup
            }
        }
        .padding(.vertical, 36)
        .padding(.horizontal, 36)
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
                    .font(.system(size: 42))
                    .foregroundColor(.blue)
                
                Text("OpenAI API Key")
                    .font(.system(size: 19.6, weight: .bold, design: .rounded))
                
                Text("Enter your OpenAI API key to enable voice transcription")
                    .font(.system(size: 9.1, weight: .regular, design: .rounded))
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
                    OnboardingActionButton(title: "Back", style: .secondary) {
                        appState.onboardingState = .welcome
                    }
                    
                    OnboardingActionButton(title: "Continue", style: .primary) {
                        validateAndContinue()
                    }
                    .disabled(apiKey.isEmpty || isValidating)
                }
                
                // Add some bottom padding to ensure buttons are visible
                Spacer().frame(height: 20)
            }
        }
        .padding(.vertical, 36)
        .padding(.horizontal, 36)
        .onAppear {
            // Pre-fill API key from appState.settings if available
            if apiKey.isEmpty, !appState.settings.apiKey.isEmpty {
                apiKey = appState.settings.apiKey
            }
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
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 42))
                    .foregroundColor(.blue)
                
                Text("Choose AI Model")
                    .font(.system(size: 19.6, weight: .bold, design: .rounded))
                
                Text("Select the Whisper model for transcription")
                    .font(.system(size: 9.1, weight: .regular, design: .rounded))
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
                OnboardingActionButton(title: "Back", style: .secondary) {
                    appState.onboardingState = .apiKeySetup
                }
                
                OnboardingActionButton(title: "Continue", style: .primary) {
                    appState.settings.saveSettings()
                    appState.onboardingState = .permissionsSetup
                }
            }
        }
        .padding(.vertical, 36)
        .padding(.horizontal, 36)
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
                    .font(.system(size: 42))
                    .foregroundColor(.blue)
                
                Text("Permissions Setup")
                    .font(.system(size: 19.6, weight: .bold, design: .rounded))
                
                Text("WolfWhisper needs a few permissions to work properly")
                    .font(.system(size: 9.1, weight: .regular, design: .rounded))
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
                    description: "Required to paste into all windows",
                    status: accessibilityPermission ? .granted : .pending,
                    action: requestAccessibilityPermission
                )
            }
            
            Spacer()
            
            HStack(spacing: 16) {
                OnboardingActionButton(title: "Back", style: .secondary) {
                    appState.onboardingState = .modelSelection
                }
                
                OnboardingActionButton(title: "Continue", style: .primary) {
                    appState.onboardingState = .hotkeySetup
                }
                .disabled(microphonePermission != .authorized)
            }
        }
        .padding(.vertical, 36)
        .padding(.horizontal, 36)
        .onAppear {
            // Pre-fill permission states from system
            microphonePermission = AVCaptureDevice.authorizationStatus(for: .audio)
            accessibilityPermission = AXIsProcessTrusted()
        }
    }
    
    private func checkPermissions() {
        microphonePermission = AVCaptureDevice.authorizationStatus(for: .audio)
        accessibilityPermission = AXIsProcessTrusted()
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
        print("🔧 DEBUG: requestAccessibilityPermission called")
        
        // First, check current status
        let initialStatus = AXIsProcessTrusted()
        print("🔧 DEBUG: Initial AXIsProcessTrusted status: \(initialStatus)")
        
        if initialStatus {
            print("🔧 DEBUG: Already has accessibility permissions")
            accessibilityPermission = true
            return
        }
        
        print("🔧 DEBUG: App bundle identifier: \(Bundle.main.bundleIdentifier ?? "unknown")")
        print("🔧 DEBUG: App executable path: \(Bundle.main.executablePath ?? "unknown")")
        print("🔧 DEBUG: App bundle path: \(Bundle.main.bundlePath)")
        
        // Create the options dictionary with prompt
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [promptKey: true] as CFDictionary
        
        print("🔧 DEBUG: About to call AXIsProcessTrustedWithOptions with prompt=true")
        print("🔧 DEBUG: Prompt key: \(promptKey)")
        
        // This should trigger the system prompt and add the app to the list
        let isTrusted = AXIsProcessTrustedWithOptions(options)
        print("🔧 DEBUG: AXIsProcessTrustedWithOptions returned: \(isTrusted)")
        
        if isTrusted {
            print("🔧 DEBUG: Permissions granted immediately")
            accessibilityPermission = true
            return
        }
        
        print("🔧 DEBUG: Permissions not granted, should have triggered system prompt")
        
        // Check if the app is now in the TCC database (might not be trusted yet, but should be listed)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let statusAfterPrompt = AXIsProcessTrusted()
            print("🔧 DEBUG: Status after 1 second: \(statusAfterPrompt)")
            
            // Try to open System Settings
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                print("🔧 DEBUG: Opening System Settings...")
                NSWorkspace.shared.open(url)
            }
        }
        
        // Check permission status after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            let finalStatus = AXIsProcessTrusted()
            print("🔧 DEBUG: Final status after 3 seconds: \(finalStatus)")
            self.checkPermissions()
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
                    .font(.system(size: 42))
                    .foregroundColor(.blue)
                
                Text("Setup Hotkey")
                    .font(.system(size: 19.6, weight: .bold, design: .rounded))
                
                Text("Choose a keyboard shortcut for global dictation")
                    .font(.system(size: 9.1, weight: .regular, design: .rounded))
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
                            .foregroundColor(.white)
                            .fontWeight(.semibold)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.accentColor)
                                    .shadow(color: Color.black.opacity(0.10), radius: 2, x: 0, y: 1)
                            )
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
                OnboardingActionButton(title: "Back", style: .secondary) {
                    appState.onboardingState = .permissionsSetup
                }
                
                OnboardingActionButton(title: "Complete Setup", style: .primary) {
                    // Now save everything including to keychain
                    appState.settings.saveSettings()
                    appState.completeOnboarding()
                }
            }
        }
        .padding(.vertical, 36)
        .padding(.horizontal, 36)
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