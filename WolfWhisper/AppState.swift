import Foundation
import SwiftUI

// The various states the application can be in.
enum AppState {
    case idle
    case recording
    case transcribing
}

// Onboarding flow states
enum OnboardingState {
    case welcome
    case apiKeySetup
    case modelSelection
    case permissionsSetup
    case hotkeySetup
    case completed
}

// Available Whisper models
enum WhisperModel: String, CaseIterable {
    case whisper1 = "whisper-1"
    
    var displayName: String {
        switch self {
        case .whisper1:
            return "Whisper-1 (Recommended)"
        }
    }
    
    var description: String {
        switch self {
        case .whisper1:
            return "OpenAI's latest Whisper model with best accuracy and speed"
        }
    }
}

// Settings model
@MainActor
class SettingsModel: ObservableObject {
    @Published var apiKey: String = ""
    @Published var selectedModel: WhisperModel = .whisper1
    @Published var hotkeyEnabled: Bool = true
    @Published var hotkeyModifiers: String = "⌘⇧" // Command + Shift
    @Published var hotkeyKey: String = "D"
    @Published var autoTranscribe: Bool = true
    @Published var showInMenuBar: Bool = false
    @Published var launchAtLogin: Bool = false
    
    private var keychainService: KeychainService {
        return KeychainService.shared
    }
    
    init() {
        loadSettings()
    }
    
    func loadSettings() {
        // Load API key from keychain only if we're past onboarding
        if UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
            loadApiKey()
        }
        
        // Load other settings from UserDefaults
        selectedModel = WhisperModel(rawValue: UserDefaults.standard.string(forKey: "selectedModel") ?? WhisperModel.whisper1.rawValue) ?? .whisper1
        hotkeyEnabled = UserDefaults.standard.bool(forKey: "hotkeyEnabled")
        hotkeyModifiers = UserDefaults.standard.string(forKey: "hotkeyModifiers") ?? "⌘⇧"
        hotkeyKey = UserDefaults.standard.string(forKey: "hotkeyKey") ?? "D"
        autoTranscribe = UserDefaults.standard.bool(forKey: "autoTranscribe")
        showInMenuBar = UserDefaults.standard.bool(forKey: "showInMenuBar")
        launchAtLogin = UserDefaults.standard.bool(forKey: "launchAtLogin")
    }
    
    func saveSettings() {
        // Save API key to keychain only if it's not empty and we've completed onboarding
        if !apiKey.isEmpty && UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
            _ = keychainService.saveApiKey(apiKey)
        }
        
        // Save other settings to UserDefaults
        UserDefaults.standard.set(selectedModel.rawValue, forKey: "selectedModel")
        UserDefaults.standard.set(hotkeyEnabled, forKey: "hotkeyEnabled")
        UserDefaults.standard.set(hotkeyModifiers, forKey: "hotkeyModifiers")
        UserDefaults.standard.set(hotkeyKey, forKey: "hotkeyKey")
        UserDefaults.standard.set(autoTranscribe, forKey: "autoTranscribe")
        UserDefaults.standard.set(showInMenuBar, forKey: "showInMenuBar")
        UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin")
    }
    
    var isConfigured: Bool {
        // Only consider configured if onboarding is complete AND API key exists
        guard UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") else {
            return false
        }
        return !apiKey.isEmpty
    }
    
    var hotkeyDisplay: String {
        return "\(hotkeyModifiers)\(hotkeyKey)"
    }
    
    func loadApiKey() {
        apiKey = keychainService.loadApiKey() ?? ""
    }
}

// An observable class to manage and publish the application's state.
@MainActor
class AppStateModel: ObservableObject {
    @Published var currentState: AppState = .idle
    @Published var statusText: String = "Ready to record"
    @Published var onboardingState: OnboardingState = .welcome
    @Published var isFirstLaunch: Bool = true
    @Published var showSettings: Bool = false
    @Published var transcribedText: String = ""
    @Published var audioLevels: [Float] = []
    @Published var wasTriggeredByHotkey: Bool = false
    @Published var needsSetup: Bool = false
    @Published var debugInfo: String = "Debug: No transcription yet"
    
    // Settings
    @Published var settings = SettingsModel()
    
    init() {
        checkFirstLaunch()
    }
    
    private func checkFirstLaunch() {
        isFirstLaunch = !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        if isFirstLaunch {
            onboardingState = .welcome
        } else {
            onboardingState = .completed
        }
    }
    
    func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        isFirstLaunch = false
        onboardingState = .completed
    }
    
    func updateState(to newState: AppState, message: String? = nil) {
        currentState = newState
        
        if let message = message {
            statusText = message
        } else {
            switch newState {
            case .idle:
                statusText = "Ready to record"
            case .recording:
                statusText = "Recording... Click to stop"
            case .transcribing:
                statusText = "Transcribing audio..."
            }
        }
    }
    
    func updateAudioLevels(_ levels: [Float]) {
        audioLevels = levels
    }
    
    func setTranscribedText(_ text: String) {
        transcribedText = text
        debugInfo = "Debug: Set text to '\(text)' (length: \(text.count))"
    }
    
    func validateSetup() {
        // Check if we need to show onboarding or settings
        if isFirstLaunch {
            // Show onboarding for first launch
            needsSetup = false
            return
        }
        
        // Check all required settings and permissions
        var missingRequirements: [String] = []
        
        // 1. Check API Key
        if settings.apiKey.isEmpty {
            missingRequirements.append("OpenAI API Key")
        }
        
        // 2. Check microphone permissions
        if !hasMicrophonePermission() {
            missingRequirements.append("Microphone Access")
        }
        
        // 3. Check accessibility permissions (for hotkeys)
        if settings.hotkeyEnabled && !hasAccessibilityPermissions() {
            missingRequirements.append("Accessibility Access")
        }
        
        if !missingRequirements.isEmpty {
            needsSetup = true
            statusText = "Setup required: \(missingRequirements.joined(separator: ", "))"
            showSettings = true
        } else {
            needsSetup = false
        }
    }
    
    private func hasMicrophonePermission() -> Bool {
        // This is a simplified check - in reality you'd use AVAudioSession
        return true // For now, assume we have it
    }
    
    private func hasAccessibilityPermissions() -> Bool {
        // Import Carbon and check accessibility permissions
        return true // For now, assume we have it - we'll implement this properly
    }
} 