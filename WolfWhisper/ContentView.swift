import SwiftUI
import AVFoundation

struct ContentView: View {
    @ObservedObject var appState: AppStateModel
    @StateObject private var audioService = AudioService.shared
    @StateObject private var transcriptionService = TranscriptionService.shared
    @StateObject private var hotkeyService = HotkeyService.shared
    
    var body: some View {
        MainAppView(appState: appState)
        .onAppear {
            setupServices()
            setupHotkey()
        }
        .onChange(of: appState.settings.hotkeyEnabled) {
            setupHotkey()
        }
        .onChange(of: appState.settings.hotkeyModifiers) {
            setupHotkey()
        }
        .onChange(of: appState.settings.hotkeyKey) {
            setupHotkey()
        }
    }
    
    private func setupServices() {
        // Set up audio service callbacks
        audioService.onStateChange = { state in
            appState.updateState(to: state)
        }
        
        audioService.onAudioLevelsUpdate = { levels in
            appState.updateAudioLevels(levels)
        }
        
        // Set up transcription service callback
        transcriptionService.onTranscriptionComplete = { result in
            Task { @MainActor in
                appState.debugInfo = "Debug: Transcription callback called!"
                switch result {
                case .success(let text):
                    appState.debugInfo = "Debug: Got transcription: '\(text)' (length: \(text.count))"
                    appState.setTranscribedText(text)
                    appState.updateState(to: .idle)
                    
                    // Always copy to clipboard
                    hotkeyService.copyToClipboard(text)
                    
                    // If triggered by hotkey, paste after a delay to ensure proper focus
                    if appState.wasTriggeredByHotkey {
                        // Delay pasting to allow floating window to close and focus to return
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            hotkeyService.pasteToActiveWindow()
                            
                            // Reset the flag after pasting is complete
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                appState.wasTriggeredByHotkey = false
                            }
                        }
                    }
                    
                case .failure(let error):
                    appState.debugInfo = "Debug: Transcription failed: \(error)"
                    appState.updateState(to: .idle, message: "Transcription failed: \(error.localizedDescription)")
                }
            }
        }
        
        // Set up hotkey callback
        hotkeyService.onHotkeyPressed = {
            handleHotkeyPressed()
        }
        
        // Validate setup on startup
        appState.validateSetup()
    }
    
    private func setupHotkey() {
        if appState.settings.hotkeyEnabled {
            hotkeyService.registerHotkey(
                modifiers: appState.settings.hotkeyModifiers,
                key: appState.settings.hotkeyKey
            )
        } else {
            hotkeyService.unregisterHotkey()
        }
    }
    
    private func handleHotkeyPressed() {
        // Mark that this was triggered by hotkey
        appState.wasTriggeredByHotkey = true
        
        switch appState.currentState {
        case .idle:
            startRecording()
        case .recording:
            stopRecording()
        case .transcribing:
            // Do nothing while transcribing
            break
        }
    }
    
    private func startRecording() {
        appState.debugInfo = "Debug: Starting recording..."
        guard appState.settings.isConfigured else {
            appState.debugInfo = "Debug: Settings not configured"
            appState.showSettings = true
            return
        }

        Task {
            do {
                try await audioService.startRecording()
                await MainActor.run {
                    appState.debugInfo = "Debug: Recording started successfully"
                }
            } catch {
                await MainActor.run {
                    appState.debugInfo = "Debug: Recording failed: \(error)"
                    appState.updateState(to: .idle, message: "Recording failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func stopRecording() {
        Task {
            do {
                await MainActor.run {
                    appState.debugInfo = "Debug: Stopping recording..."
                }
                let audioData = try await audioService.stopRecording()
                
                await MainActor.run {
                    appState.updateState(to: .transcribing)
                    appState.debugInfo = "Debug: Got \(audioData.count) bytes, transcribing..."
                }
                
                // Transcribe the audio
                try await transcriptionService.transcribe(
                    audioData: audioData,
                    apiKey: appState.settings.apiKey,
                    model: appState.settings.selectedModel.rawValue
                )
                await MainActor.run {
                    appState.debugInfo = "Debug: Transcription request sent, waiting for response..."
                }
                
            } catch {
                await MainActor.run {
                    appState.debugInfo = "Debug: Recording/transcription failed: \(error)"
                    appState.updateState(to: .idle, message: "Failed to process recording: \(error.localizedDescription)")
                }
            }
        }
    }
}

struct MainAppView: View {
    @ObservedObject var appState: AppStateModel
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Modern background with subtle gradient
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(NSColor.windowBackgroundColor),
                        Color(NSColor.windowBackgroundColor).opacity(0.8)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: adaptiveSpacing(for: geometry.size)) {
                    // Header
                    HeaderView(appState: appState)
                    
                    VStack(spacing: adaptiveContentSpacing(for: geometry.size)) {
                        // Main recording button - properly sized
                        RecordingButton(
                            state: appState.currentState,
                            isRecording: appState.currentState == .recording,
                            audioLevels: appState.audioLevels,
                            action: {
                                handleRecordingButtonTap(appState: appState)
                            }
                        )
                        
                        // Status text
                        Text(appState.statusText)
                            .font(.title3)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .animation(.easeInOut, value: appState.statusText)
                        
                        // Debug info - only show meaningful information
                        if !appState.debugInfo.isEmpty && 
                           !appState.debugInfo.contains("No transcription yet") &&
                           !appState.debugInfo.contains("Debug: No transcription yet") {
                            Text(appState.debugInfo)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                                .animation(.easeInOut, value: appState.debugInfo)
                        }
                    }
                    
                    // Transcribed text - modern card design
                    TranscribedTextCard(text: appState.transcribedText)
                    
                    Spacer(minLength: 0)
                    
                    // Footer with hotkey info
                    FooterView(appState: appState)
                }
                .padding(.top, adaptiveTopPadding(for: geometry.size))
                .padding(.horizontal, adaptiveHorizontalPadding(for: geometry.size))
                .padding(.bottom, adaptiveBottomPadding(for: geometry.size))
            }
        }
        .frame(minWidth: 400, maxWidth: 600, minHeight: 500, maxHeight: 700)
    }
    
    // Adaptive spacing functions for responsiveness
    private func adaptiveSpacing(for size: CGSize) -> CGFloat {
        return size.height > 600 ? 24 : 16
    }
    
    private func adaptiveContentSpacing(for size: CGSize) -> CGFloat {
        return size.height > 600 ? 20 : 12
    }
    
    private func adaptiveTopPadding(for size: CGSize) -> CGFloat {
        return size.height > 600 ? 20 : 15
    }
    
    private func adaptiveHorizontalPadding(for size: CGSize) -> CGFloat {
        return size.width > 500 ? 30 : 20
    }
    
    private func adaptiveBottomPadding(for size: CGSize) -> CGFloat {
        return size.height > 600 ? 20 : 15
    }
}

struct HeaderView: View {
    @ObservedObject var appState: AppStateModel
    
    var body: some View {
        GeometryReader { geometry in
            HStack {
                // App title and logo with adaptive sizing
                HStack(spacing: adaptiveLogoSpacing(for: geometry.size)) {
                    Image(systemName: "waveform")
                        .font(.system(size: adaptiveLogoSize(for: geometry.size), weight: .medium))
                        .foregroundColor(.blue)
                    
                    Text("WolfWhisper")
                        .font(.system(size: adaptiveTitleSize(for: geometry.size), weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                }
                
                Spacer(minLength: 20) // Ensure minimum space between title and settings
                
                // Settings button - always visible with adaptive sizing
                Button(action: {
                    appState.showSettings = true
                }) {
                    Image(systemName: "gear")
                        .font(.system(size: adaptiveSettingsIconSize(for: geometry.size), weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: adaptiveSettingsButtonSize(for: geometry.size), 
                               height: adaptiveSettingsButtonSize(for: geometry.size))
                        .background(
                            Circle()
                                .fill(.blue)
                                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .help("Settings")
                .animation(.easeInOut(duration: 0.2), value: appState.showSettings)
            }
            .padding(.horizontal, adaptiveHeaderPadding(for: geometry.size))
            .padding(.top, adaptiveHeaderTopPadding(for: geometry.size))
        }
        .frame(height: 60) // Fixed height to ensure consistent layout
    }
    
    private func adaptiveLogoSpacing(for size: CGSize) -> CGFloat {
        return size.width > 500 ? 12 : 8
    }
    
    private func adaptiveLogoSize(for size: CGSize) -> CGFloat {
        return size.width > 500 ? 20 : 18
    }
    
    private func adaptiveTitleSize(for size: CGSize) -> CGFloat {
        return size.width > 500 ? 20 : 18
    }
    
    private func adaptiveSettingsIconSize(for size: CGSize) -> CGFloat {
        return size.width > 500 ? 18 : 16
    }
    
    private func adaptiveSettingsButtonSize(for size: CGSize) -> CGFloat {
        return size.width > 500 ? 40 : 36
    }
    
    private func adaptiveHeaderPadding(for size: CGSize) -> CGFloat {
        return size.width > 500 ? 8 : 4
    }
    
    private func adaptiveHeaderTopPadding(for size: CGSize) -> CGFloat {
        return size.height > 600 ? 8 : 4
    }
}

struct FooterView: View {
    @ObservedObject var appState: AppStateModel
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: adaptiveFooterSpacing(for: geometry.size)) {
                if appState.settings.hotkeyEnabled {
                    HStack(spacing: adaptiveHotkeySpacing(for: geometry.size)) {
                        Text("Global Hotkey:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(appState.settings.hotkeyDisplay)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .padding(.horizontal, adaptiveHotkeyPadding(for: geometry.size))
                            .padding(.vertical, 5)
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(.primary.opacity(0.2), lineWidth: 0.5)
                            )
                    }
                    
                    Text("Press the hotkey from any app to start dictation")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, adaptiveFooterHorizontalPadding(for: geometry.size))
        }
        .frame(height: appState.settings.hotkeyEnabled ? 60 : 0)
    }
    
    private func adaptiveFooterSpacing(for size: CGSize) -> CGFloat {
        return size.height > 600 ? 12 : 8
    }
    
    private func adaptiveHotkeySpacing(for size: CGSize) -> CGFloat {
        return size.width > 500 ? 12 : 8
    }
    
    private func adaptiveHotkeyPadding(for size: CGSize) -> CGFloat {
        return size.width > 500 ? 10 : 8
    }
    
    private func adaptiveFooterHorizontalPadding(for size: CGSize) -> CGFloat {
        return size.width > 500 ? 20 : 16
    }
}

// Helper function to handle recording button tap
@MainActor
private func handleRecordingButtonTap(appState: AppStateModel) {
    switch appState.currentState {
    case .idle:
        // Check if API key is configured
        guard appState.settings.isConfigured else {
            appState.showSettings = true
            return
        }
        
        // Mark as NOT triggered by hotkey (button click)
        appState.wasTriggeredByHotkey = false
        
        // Start recording
        Task {
            do {
                try await AudioService.shared.startRecording()
            } catch {
                await MainActor.run {
                    appState.updateState(to: .idle, message: "Recording failed: \(error.localizedDescription)")
                }
            }
        }
        
    case .recording:
        // Stop recording and transcribe
        Task {
            do {
                let audioData = try await AudioService.shared.stopRecording()
                
                await MainActor.run {
                    appState.updateState(to: .transcribing)
                }
                
                // Transcribe the audio
                try await TranscriptionService.shared.transcribe(
                    audioData: audioData,
                    apiKey: appState.settings.apiKey,
                    model: appState.settings.selectedModel.rawValue
                )
                
            } catch {
                await MainActor.run {
                    appState.updateState(to: .idle, message: "Failed to process recording: \(error.localizedDescription)")
                }
            }
        }
        
    case .transcribing:
        // Do nothing while transcribing
        break
    }
}

// Modern transcribed text card component
struct TranscribedTextCard: View {
    let text: String
    
    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Transcribed Text")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    if !text.isEmpty {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 16, weight: .medium))
                    }
                }
                
                // Adaptive content area
                if text.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "quote.bubble")
                            .font(.system(size: 32, weight: .light))
                            .foregroundColor(.secondary.opacity(0.5))
                        
                        Text("No transcription yet")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, adaptiveEmptyStatePadding(for: geometry.size))
                } else {
                    ScrollView {
                        Text(text)
                            .font(.body)
                            .foregroundColor(.primary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 4)
                    }
                    .frame(maxHeight: adaptiveTextHeight(for: geometry.size))
                }
            }
            .padding(adaptiveCardPadding(for: geometry.size))
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.primary.opacity(0.1), lineWidth: 1)
            )
        }
        .frame(minHeight: 100)
    }
    
    private func adaptiveCardPadding(for size: CGSize) -> CGFloat {
        return size.width > 500 ? 20 : 16
    }
    
    private func adaptiveEmptyStatePadding(for size: CGSize) -> CGFloat {
        return size.height > 600 ? 40 : 20
    }
    
    private func adaptiveTextHeight(for size: CGSize) -> CGFloat {
        return max(60, size.height * 0.2) // At least 60px, or 20% of window height
    }
}

#Preview {
    ContentView(appState: AppStateModel())
} 