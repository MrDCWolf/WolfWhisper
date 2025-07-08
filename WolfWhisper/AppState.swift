import Foundation
import SwiftUI
import ApplicationServices
import AVFoundation
import AppKit
import UniformTypeIdentifiers
import Combine

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

// Available Gemini models
enum GeminiModel: String, CaseIterable {
    case gemini25Flash = "gemini-2.5-flash"
    case gemini25FlashLite = "gemini-2.5-flash-lite-preview-06-17"
    
    var displayName: String {
        switch self {
        case .gemini25Flash:
            return "Gemini 2.5 Flash"
        case .gemini25FlashLite:
            return "Gemini 2.5 Flash Lite"
        }
    }
    
    var description: String {
        switch self {
        case .gemini25Flash:
            return "Google's latest Gemini 2.5 Flash model for fast, accurate transcription"
        case .gemini25FlashLite:
            return "Lightweight Gemini 2.5 Flash model optimized for speed"
        }
    }
}

// Available transcription providers
enum TranscriptionProvider: String, CaseIterable {
    case openAI = "openai"
    case gemini = "gemini"
    
    var displayName: String {
        switch self {
        case .openAI:
            return "OpenAI"
        case .gemini:
            return "Google Gemini"
        }
    }
    
    var description: String {
        switch self {
        case .openAI:
            return "OpenAI's Whisper models for speech-to-text transcription"
        case .gemini:
            return "Google's Gemini models with built-in transcription and cleanup"
        }
    }
}

// Settings model
@MainActor
class SettingsModel: ObservableObject {
    @Published var apiKey: String = ""
    @Published var selectedModel: WhisperModel = .whisper1
    @Published var hotkeyEnabled: Bool = true
    @Published var hotkeyModifiers: UInt = 0 // Raw modifier flags
    @Published var hotkeyKey: UInt16 = 0 // Raw key code
    @Published var hotkeyDisplay: String = "⌘⇧D" // Stored property for UI display
    @Published var showInMenuBar: Bool = false
    @Published var launchAtLogin: Bool = false
    
    // Provider and Gemini settings
    @Published var selectedProvider: TranscriptionProvider = .openAI
    @Published var geminiApiKey: String = ""
    @Published var selectedGeminiModel: GeminiModel = .gemini25Flash
    
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
        
        // Load hotkey settings with proper defaults for ⌘⇧D
        let savedModifiers = UserDefaults.standard.object(forKey: "hotkeyModifiers") as? Int
        let savedKey = UserDefaults.standard.object(forKey: "hotkeyKey") as? Int
        
        if savedModifiers == nil || savedKey == nil {
            // Set default ⌘⇧D hotkey using Carbon modifier flags
            hotkeyModifiers = UInt(256 + 512) // cmdKey + shiftKey in Carbon
            hotkeyKey = 2 // D key
            hotkeyDisplay = "⌘⇧D"
            // Save the defaults immediately
            UserDefaults.standard.set(Int(hotkeyModifiers), forKey: "hotkeyModifiers")
            UserDefaults.standard.set(Int(hotkeyKey), forKey: "hotkeyKey")
            UserDefaults.standard.set(hotkeyDisplay, forKey: "hotkeyDisplay")
        } else {
            hotkeyModifiers = UInt(savedModifiers!)
            hotkeyKey = UInt16(savedKey!)
            hotkeyDisplay = UserDefaults.standard.string(forKey: "hotkeyDisplay") ?? "⌘⇧D"
        }
        
        showInMenuBar = UserDefaults.standard.bool(forKey: "showInMenuBar")
        launchAtLogin = UserDefaults.standard.bool(forKey: "launchAtLogin")
        
        // Load provider settings
        selectedProvider = TranscriptionProvider(rawValue: UserDefaults.standard.string(forKey: "selectedProvider") ?? TranscriptionProvider.openAI.rawValue) ?? .openAI
        selectedGeminiModel = GeminiModel(rawValue: UserDefaults.standard.string(forKey: "selectedGeminiModel") ?? GeminiModel.gemini25Flash.rawValue) ?? .gemini25Flash
        
        // Load Gemini API key from keychain
        if UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
            loadGeminiApiKey()
        }
    }
    
    func saveSettings() {
        // Save API key to keychain only if it's not empty and we've completed onboarding
        if !apiKey.isEmpty && UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
            _ = keychainService.saveApiKey(apiKey)
        }
        
        // Save other settings to UserDefaults
        UserDefaults.standard.set(selectedModel.rawValue, forKey: "selectedModel")
        UserDefaults.standard.set(hotkeyEnabled, forKey: "hotkeyEnabled")
        UserDefaults.standard.set(Int(hotkeyModifiers), forKey: "hotkeyModifiers")
        UserDefaults.standard.set(Int(hotkeyKey), forKey: "hotkeyKey")
        UserDefaults.standard.set(hotkeyDisplay, forKey: "hotkeyDisplay")
        UserDefaults.standard.set(showInMenuBar, forKey: "showInMenuBar")
        UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin")
        
        // Save provider settings
        UserDefaults.standard.set(selectedProvider.rawValue, forKey: "selectedProvider")
        UserDefaults.standard.set(selectedGeminiModel.rawValue, forKey: "selectedGeminiModel")
        
        // Save Gemini API key to keychain if not empty and onboarding is complete
        if !geminiApiKey.isEmpty && UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
            _ = keychainService.saveGeminiApiKey(geminiApiKey)
        }
    }
    
    var isConfigured: Bool {
        // Only consider configured if onboarding is complete AND appropriate API key exists
        guard UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") else {
            return false
        }
        
        switch selectedProvider {
        case .openAI:
            return !apiKey.isEmpty
        case .gemini:
            return !geminiApiKey.isEmpty
        }
    }
    

    
    func loadApiKey() {
        apiKey = keychainService.loadApiKey() ?? ""
    }
    
    func loadGeminiApiKey() {
        geminiApiKey = keychainService.loadGeminiApiKey() ?? ""
    }
    
    func exportDebugLog() {
        let debugInfo = generateDebugInfo()
        
        let savePanel = NSSavePanel()
        savePanel.title = "Export Debug Log"
        savePanel.nameFieldStringValue = "wolfwhisper-debug-\(Date().timeIntervalSince1970).txt"
        savePanel.allowedContentTypes = [.plainText]
        
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                do {
                    try debugInfo.write(to: url, atomically: true, encoding: .utf8)
                } catch {
                    print("Failed to export debug log: \(error)")
                }
            }
        }
    }
    
    private func generateDebugInfo() -> String {
        var info = [String]()
        
        info.append("WolfWhisper Debug Log")
        info.append("Generated: \(Date())")
        info.append("Version: 1.4.0")
        info.append("")
        
        info.append("=== Settings ===")
        info.append("Selected Provider: \(selectedProvider.displayName)")
        info.append("Selected Model: \(selectedModel.rawValue)")
        info.append("Selected Gemini Model: \(selectedGeminiModel.rawValue)")
        info.append("Hotkey Enabled: \(hotkeyEnabled)")
        info.append("Hotkey Display: \(hotkeyDisplay)")
        info.append("Hotkey Modifiers: \(hotkeyModifiers)")
        info.append("Hotkey Key: \(hotkeyKey)")
        info.append("Show in Menu Bar: \(showInMenuBar)")
        info.append("Launch at Login: \(launchAtLogin)")

        info.append("")
        
        info.append("=== System ===")
        info.append("macOS Version: \(ProcessInfo.processInfo.operatingSystemVersionString)")
        info.append("Current Microphone: \(AudioService.shared.getCurrentMicrophoneName())")
        info.append("")
        
        info.append("=== Permissions ===")
        info.append("Microphone Permission: \(checkMicrophonePermission())")
        info.append("Accessibility Permission: \(checkAccessibilityPermission())")
        info.append("")
        
        info.append("=== UserDefaults ===")
        let defaults = UserDefaults.standard
        let keys = ["selectedProvider", "selectedModel", "selectedGeminiModel", "hotkeyEnabled", "hotkeyModifiers", "hotkeyKey", "hotkeyDisplay", "showInMenuBar", "launchAtLogin", "hasCompletedOnboarding"]
        for key in keys {
            info.append("\(key): \(defaults.object(forKey: key) ?? "nil")")
        }
        
        return info.joined(separator: "\n")
    }
    
    private func checkMicrophonePermission() -> String {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: return "Granted"
        case .denied: return "Denied"
        case .restricted: return "Restricted"
        case .notDetermined: return "Not Determined"
        @unknown default: return "Unknown"
        }
    }
    
    private func checkAccessibilityPermission() -> String {
        return AXIsProcessTrusted() ? "Granted" : "Denied"
    }
    
    func resetAllSettings() {
        // Reset UserDefaults
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "selectedProvider")
        defaults.removeObject(forKey: "selectedModel")
        defaults.removeObject(forKey: "selectedGeminiModel")
        defaults.removeObject(forKey: "hotkeyEnabled")
        defaults.removeObject(forKey: "hotkeyModifiers")
        defaults.removeObject(forKey: "hotkeyKey")
        defaults.removeObject(forKey: "hotkeyDisplay")
        defaults.removeObject(forKey: "showInMenuBar")
        defaults.removeObject(forKey: "launchAtLogin")
        defaults.removeObject(forKey: "hasCompletedOnboarding")
        
        // Clear keychain
        keychainService.deleteApiKey()
        keychainService.deleteGeminiApiKey()
        
        // Reload settings
        loadSettings()
    }
    
    func checkAllPermissions() {
        // Request microphone permission
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            DispatchQueue.main.async {
                print("Microphone permission: \(granted ? "granted" : "denied")")
            }
        }
        
        // Check accessibility permission
        let hasAccessibility = AXIsProcessTrusted()
        if !hasAccessibility {
            // Open System Preferences to Security & Privacy
            let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
            NSWorkspace.shared.open(url)
        }
        
        print("Accessibility permission: \(hasAccessibility ? "granted" : "denied - opening System Preferences")")
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
    
    private var settingsObserver: AnyCancellable?
    
    init() {
        checkFirstLaunch()
        setupSettingsObserver()
    }
    
    private func setupSettingsObserver() {
        // Listen to changes in the settings model and re-publish them
        settingsObserver = settings.objectWillChange.sink { [weak self] _ in
            // This will trigger UI updates when any settings property changes
            self?.objectWillChange.send()
        }
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
        // Check if the app has accessibility permissions
        let trusted = AXIsProcessTrusted()
        return trusted
    }
    
    func startRecording() async {
        // This will be called from menu bar - delegate to audio service
        updateState(to: .recording)
        // The actual recording logic should be handled by ContentView or AudioService
    }
    
    func requestAccessibilityPermission() {
        // Open System Preferences to Accessibility settings
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
} 