import Foundation
import SwiftUI
import AVFoundation
@preconcurrency import ApplicationServices
import AppKit
import UniformTypeIdentifiers
import Combine
import Carbon

// The various states the application can be in.
enum AppStateValue: String {
    case idle
    case recording
    case transcribing
    
    var statusText: String {
        switch self {
        case .idle:
            return "Ready"
        case .recording:
            return "Recording..."
        case .transcribing:
            return "Transcribing..."
        }
    }
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
enum WhisperModel: String, CaseIterable, Identifiable {
    case whisper1 = "whisper-1"
    
    var id: String { self.rawValue }
    
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
enum GeminiModel: String, CaseIterable, Identifiable {
    case gemini25Flash = "gemini-2.5-flash"
    case gemini25FlashLite = "gemini-2.5-flash-lite-preview-06-17"
    
    var id: String { self.rawValue }
    
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
enum TranscriptionProvider: String, CaseIterable, Identifiable {
    case openAI = "OpenAI"
    case gemini = "Google Gemini"

    var id: String { self.rawValue }

    var models: [String] {
        switch self {
        case .openAI:
            return ["whisper-1"]
        case .gemini:
            return ["gemini-2.5-flash", "gemini-2.5-flash-lite-preview-06-17"]
        }
    }
    
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

// Main application state
@MainActor
class AppState: ObservableObject {
    @Published var currentState: AppStateValue = .idle
    @Published var transcribedText: String = ""
    @Published var statusText: String = "Ready"
    @Published var audioLevels: Float = 0.0
    @Published var audioLevelHistory: [Float] = Array(repeating: 0.0, count: 32)
    @Published var debugInfo: String = ""
    @Published var showSettings: Bool = false

    // Settings
    @Published var openAIAPIKey: String = ""
    @Published var selectedOpenAIModel: String = "whisper-1"
    @Published var hotkeyEnabled: Bool = true
    @Published var hotkeyModifiers: NSEvent.ModifierFlags = .command
    @Published var hotkeyKey: String = "D"
    @Published var hotkeyDisplay: String = "⌘D"
    @Published var selectedProvider: TranscriptionProvider = .openAI
    @Published var geminiAPIKey: String = ""
    @Published var selectedGeminiModel: String = "gemini-2.5-flash"
    @Published var showInMenuBar: Bool = true
    @Published var launchAtLogin: Bool = false
    
    // Onboarding
    @Published var isFirstLaunch: Bool
    @Published var hasCompletedOnboarding: Bool
    @Published var onboardingState: OnboardingState = .welcome

    private let openAIKeyAccount = "openai"
    private let geminiKeyAccount = "gemini"
    
    init() {
        self.isFirstLaunch = !UserDefaults.standard.bool(forKey: "hasLaunchedBefore")
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        
        if isFirstLaunch {
            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
        }

        Task {
            await loadSettings()
        }
    }

    func updateState(to newState: AppStateValue, message: String? = nil) {
        self.currentState = newState
        self.statusText = message ?? newState.statusText
    }

    func updateAudioLevels(_ levels: Float) {
        self.audioLevels = levels
        self.audioLevelHistory.removeFirst()
        self.audioLevelHistory.append(levels)
    }
    
    func loadSettings() async {
        if UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
            openAIAPIKey = await KeychainService.shared.loadAPIKey(for: openAIKeyAccount) ?? ""
            geminiAPIKey = await KeychainService.shared.loadAPIKey(for: geminiKeyAccount) ?? ""
        }
        
        selectedOpenAIModel = UserDefaults.standard.string(forKey: "selectedOpenAIModel") ?? "whisper-1"
        selectedGeminiModel = UserDefaults.standard.string(forKey: "selectedGeminiModel") ?? "gemini-2.5-flash"
        
        let savedModifiers = UserDefaults.standard.integer(forKey: "hotkeyModifiers")
        if let savedKey = UserDefaults.standard.string(forKey: "hotkeyKey"), savedModifiers != 0 {
            hotkeyModifiers = NSEvent.ModifierFlags(rawValue: UInt(savedModifiers))
            hotkeyKey = savedKey
            hotkeyDisplay = UserDefaults.standard.string(forKey: "hotkeyDisplay") ?? "⌘D"
        } else {
            hotkeyModifiers = .command
            hotkeyKey = "D"
            hotkeyDisplay = "⌘D"
        }
    }
    
    func saveSettings() async {
        _ = await KeychainService.shared.saveAPIKey(openAIAPIKey, for: openAIKeyAccount)
        _ = await KeychainService.shared.saveAPIKey(geminiAPIKey, for: geminiKeyAccount)
        
        UserDefaults.standard.set(selectedOpenAIModel, forKey: "selectedOpenAIModel")
        UserDefaults.standard.set(selectedGeminiModel, forKey: "selectedGeminiModel")
        UserDefaults.standard.set(hotkeyEnabled, forKey: "hotkeyEnabled")
        UserDefaults.standard.set(Int(hotkeyModifiers.rawValue), forKey: "hotkeyModifiers")
        UserDefaults.standard.set(hotkeyKey, forKey: "hotkeyKey")
        UserDefaults.standard.set(hotkeyDisplay, forKey: "hotkeyDisplay")
        UserDefaults.standard.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding")
        UserDefaults.standard.set(selectedProvider.rawValue, forKey: "selectedProvider")
        UserDefaults.standard.set(showInMenuBar, forKey: "showInMenuBar")
        UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin")
    }
    
    func isConfigured() -> Bool {
        return !openAIAPIKey.isEmpty || !geminiAPIKey.isEmpty
    }
    
    func updateHotkeyDisplay() {
        var displayString = ""
        if hotkeyModifiers.contains(.command) { displayString += "⌘" }
        if hotkeyModifiers.contains(.shift) { displayString += "⇧" }
        if hotkeyModifiers.contains(.option) { displayString += "⌥" }
        if hotkeyModifiers.contains(.control) { displayString += "⌃" }
        displayString += hotkeyKey.uppercased()
        hotkeyDisplay = displayString
    }

    // Accessibility
    @Published var accessibilityEnabled: Bool = AXIsProcessTrusted()

    func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let _ = AXIsProcessTrustedWithOptions(options)
    }

    func checkAccessibilityPermission() {
        accessibilityEnabled = AXIsProcessTrusted()
    }

    func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
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
        info.append("Version: 2.5.0")
        info.append("")
        
        info.append("=== Settings ===")
        info.append("Selected Provider: \(selectedProvider.rawValue)")
        info.append("Selected OpenAI Model: \(selectedOpenAIModel)")
        info.append("Selected Gemini Model: \(selectedGeminiModel)")
        info.append("Hotkey Enabled: \(hotkeyEnabled)")
        info.append("Hotkey: \(hotkeyDisplay)")
        info.append("Show in Menu Bar: \(showInMenuBar)")
        info.append("Launch at Login: \(launchAtLogin)")
        info.append("")
        
        info.append("=== State ===")
        info.append("Current State: \(currentState)")
        info.append("Status Text: \(statusText)")
        info.append("Accessibility Enabled: \(accessibilityEnabled)")
        info.append("Is First Launch: \(isFirstLaunch)")
        info.append("Onboarding State: \(onboardingState)")
        
        return info.joined(separator: "\n")
    }
} 