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
                NSLog("DEBUG: ==================== TRANSCRIPTION CALLBACK ====================")
                NSLog("DEBUG: wasRecordingStartedByHotkey = \(appState.wasRecordingStartedByHotkey)")
                
                switch result {
                case .success(let text):
                    appState.debugInfo = "Debug: Got transcription: '\(text)' (length: \(text.count))"
                    NSLog("DEBUG: Got transcription: '\(text)' (length: \(text.count))")
                    
                    // Always update the main app UI to show the transcription
                    appState.updateState(to: .idle)
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    let hasNormalChars = trimmed.range(of: "[A-Za-z0-9]", options: .regularExpression) != nil
                    if trimmed.isEmpty || !hasNormalChars {
                        appState.transcribedText = "No speech detected"
                    } else {
                        appState.transcribedText = text
                    }
                    
                    // Always copy to clipboard
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(text, forType: .string)
                    NSLog("DEBUG: Text copied to clipboard")
                    
                    if appState.wasRecordingStartedByHotkey {
                        NSLog("DEBUG: ===== HOTKEY RECORDING PATH =====")
                        NSLog("DEBUG: Showing in main app (background) and pasting to active window")
                        
                        // For hotkey recordings, also paste to the active window using new AXUIElement method
                        hotkeyService.setTextToPaste(text)
                        hotkeyService.pasteToActiveWindow()
                    } else {
                        NSLog("DEBUG: ===== MANUAL RECORDING PATH =====")
                        NSLog("DEBUG: Showing in main app only")
                    }
                    
                case .failure(let error):
                    appState.debugInfo = "Debug: Transcription failed: \(error.localizedDescription)"
                    NSLog("DEBUG: Transcription failed: \(error.localizedDescription)")
                    appState.updateState(to: .idle, message: "Error: \(error.localizedDescription)")
                }
                
                NSLog("DEBUG: Resetting wasRecordingStartedByHotkey flag")
                appState.wasRecordingStartedByHotkey = false
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
        NSLog("🔧 DEBUG: setupHotkey called - enabled: \(appState.settings.hotkeyEnabled)")
        NSLog("🔧 DEBUG: Hotkey modifiers: \(appState.settings.hotkeyModifiers), key: \(appState.settings.hotkeyKey)")
        
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
        NSLog("🔥 DEBUG: ==================== HOTKEY PRESSED ====================")
        NSLog("🔥 DEBUG: Current state: \(appState.currentState)")
        NSLog("🔥 DEBUG: Setting wasRecordingStartedByHotkey = true")
        
        // Set the flag to indicate this recording was started by hotkey
        appState.wasRecordingStartedByHotkey = true
        
        NSLog("🔥 DEBUG: Flag set, current state: \(appState.currentState)")
        
        if appState.currentState == .idle {
            NSLog("🔥 DEBUG: State is idle, starting recording...")
            startRecording()
        } else if appState.currentState == .recording {
            NSLog("🔥 DEBUG: State is recording, stopping recording...")
            stopRecording()
        } else {
            NSLog("🔥 DEBUG: State is \(appState.currentState), no action taken")
        }
        
        NSLog("🔥 DEBUG: handleHotkeyPressed completed")
    }
    
    private func startRecording() {
        print("DEBUG: startRecording called")
        print("DEBUG: wasRecordingStartedByHotkey = \(appState.wasRecordingStartedByHotkey)")
        
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
                    print("DEBUG: Recording started successfully, wasRecordingStartedByHotkey = \(appState.wasRecordingStartedByHotkey)")
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
        print("DEBUG: stopRecording called")
        print("DEBUG: wasRecordingStartedByHotkey = \(appState.wasRecordingStartedByHotkey)")
        
        Task {
            do {
                await MainActor.run {
                    appState.debugInfo = "Debug: Stopping recording..."
                    print("DEBUG: About to stop recording, wasRecordingStartedByHotkey = \(appState.wasRecordingStartedByHotkey)")
                }
                let audioData = try await audioService.stopRecording()
                
                await MainActor.run {
                    appState.updateState(to: .transcribing)
                    appState.debugInfo = "Debug: Got \(audioData.count) bytes, transcribing..."
                    print("DEBUG: Got audio data, starting transcription, wasRecordingStartedByHotkey = \(appState.wasRecordingStartedByHotkey)")
                }
                
                // Transcribe the audio
                try await transcriptionService.transcribe(
                    audioData: audioData,
                    apiKey: appState.settings.apiKey,
                    model: appState.settings.selectedModel.rawValue
                )
                await MainActor.run {
                    appState.debugInfo = "Debug: Transcription request sent, waiting for response..."
                    print("DEBUG: Transcription request sent, wasRecordingStartedByHotkey = \(appState.wasRecordingStartedByHotkey)")
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
        ZStack {
            // Premium background with gradient and blur effects
            GeometryReader { geometry in
                ZStack {
                    // Base gradient background
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.4, green: 0.6, blue: 0.8).opacity(0.3),
                            Color(red: 0.8, green: 0.6, blue: 0.4).opacity(0.3),
                            Color(red: 0.5, green: 0.8, blue: 0.6).opacity(0.3)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    
                    // Overlay blur effect
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .opacity(0.8)
                }
                .ignoresSafeArea()
            }
            
            VStack(spacing: 10) {
                // Modern Header with Wolf Logo
                ModernHeaderView(appState: appState)
                
                // Central Recording Interface
                VStack(spacing: 6) {
                    // Glass-style Recording Button
                    ModernRecordingButton(
                        state: appState.currentState,
                        isRecording: appState.currentState == .recording,
                        audioLevels: appState.audioLevels,
                        appState: appState,
                        action: {
                            handleRecordingButtonTap(appState: appState)
                        }
                    )
                    
                    // Status text with modern styling
                    Text(appState.statusText)
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundStyle(.primary)
                        .transition(.opacity.combined(with: .scale))
                        .animation(.easeInOut(duration: 0.3), value: appState.statusText)
                    
                    // Accessibility permission button removed - no longer needed
                }
                
                // Modern Transcription Panel
                ModernTranscriptionPanel(text: appState.transcribedText)
                
                // Sleek Footer with Hotkey
                ModernFooterView(appState: appState)
            }
            .padding(.top, 4)
            .padding(.horizontal, 17.5)
            .padding(.bottom, 10.5)
        }
        .frame(minWidth: 380)
    }
    

}

struct ModernHeaderView: View {
    @ObservedObject var appState: AppStateModel
    
    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            // Modern Wolf Logo
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 50, height: 50)
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
                
                Image(systemName: "pawprint.circle.fill")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(.white)
                    .symbolRenderingMode(.hierarchical)
            }
            
            // App Title with Modern Typography
            Text("WolfWhisper")
                .font(.system(size: 19.6, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            
            Spacer()
        }
        .padding(.horizontal, 4)
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
        appState.wasRecordingStartedByHotkey = false
        
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



struct ModernRecordingButton: View {
    let state: AppState
    let isRecording: Bool
    let audioLevels: [Float]
    @ObservedObject var appState: AppStateModel
    let action: () -> Void
    
    @State private var isPressed = false
    @State private var pulseScale: CGFloat = 1.0
    @State private var glowOpacity: Double = 0.0
    
    var body: some View {
        ZStack {
            // Outer glow ring for recording state
            if isRecording {
                Circle()
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.red.opacity(0.8),
                                Color.orange.opacity(0.6),
                                Color.red.opacity(0.4)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 3
                    )
                    .frame(width: 130, height: 130)
                    .scaleEffect(pulseScale)
                    .opacity(glowOpacity)
                    .blur(radius: 2)
            }
            
            // Main glassmorphic button
            ZStack {
                // Glass background
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 100, height: 100)
                    .overlay(
                        Circle()
                            .stroke(.white.opacity(0.3), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
                    .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                
                // Content based on state
                Group {
                    switch state {
                    case .idle:
                        if appState.transcribedText.isEmpty {
                            ModernIdleContent()
                        } else {
                            ModernCompletedContent()
                        }
                    case .recording:
                        ModernRecordingContent(audioLevels: audioLevels, appState: appState)
                    case .transcribing:
                        ModernTranscribingContentNew()
                    }
                }
            }
        }
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .onTapGesture {
            // Add haptic feedback
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
            action()
        }
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, perform: {}, onPressingChanged: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        })
        .onAppear {
            if isRecording {
                startRecordingAnimation()
            }
        }
        .onChange(of: isRecording) { _, recording in
            if recording {
                startRecordingAnimation()
            } else {
                stopRecordingAnimation()
            }
        }
    }
    
    private func startRecordingAnimation() {
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            pulseScale = 1.2
            glowOpacity = 0.8
        }
    }
    
    private func stopRecordingAnimation() {
        withAnimation(.easeInOut(duration: 0.3)) {
            pulseScale = 1.0
            glowOpacity = 0.0
        }
    }
}

struct ModernIdleContent: View {
    var body: some View {
        Image(systemName: "mic.fill")
            .font(.system(size: 33.6, weight: .medium))
            .foregroundStyle(.white)
            .symbolRenderingMode(.hierarchical)
    }
}

struct ModernRecordingContent: View {
    let audioLevels: [Float]
    @ObservedObject var appState: AppStateModel
    @State private var waveAnimation: Bool = false
    
    @ViewBuilder
    private var miniVisualization: some View {
        switch appState.currentState {
        case .recording:
            MiniWaveVisualizer(audioLevels: audioLevels)
        case .transcribing:
            MiniTranscribingVisualizer()
        case .idle:
            if appState.transcribedText.isEmpty {
                MiniWaveVisualizer(audioLevels: audioLevels)
            } else {
                MiniClipboardVisualizer()
            }
        }
    }
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(Color.white.opacity(0.1))
                .frame(width: 70, height: 70)
            
                                // Mini visualization based on current state
                    miniVisualization
                .frame(width: 60, height: 24)
        }
        .onAppear {
            waveAnimation = true
        }
    }
}



struct ModernTranscribingContentNew: View {
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(Color.white.opacity(0.1))
                .frame(width: 70, height: 70)
            
            // Beautiful rolling rainbow waveform 
            MiniTranscribingVisualizer()
                .frame(width: 60, height: 24)
        }
    }
}

struct ModernCompletedContent: View {
    @State private var showMicrophoneIcon = false
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(Color.white.opacity(0.1))
                .frame(width: 70, height: 70)
            
            // Show either clipboard animation or default microphone icon
            if showMicrophoneIcon {
                // Default microphone icon
                Image(systemName: "mic.fill")
                    .font(.system(size: 33.6, weight: .medium))
                    .foregroundStyle(.white)
                    .symbolRenderingMode(.hierarchical)
                    .transition(.opacity.combined(with: .scale))
            } else {
                // Beautiful clipboard animation
                MiniClipboardVisualizer()
                    .scaleEffect(2.5) // Scale up for main window visibility
            }
        }
        .onAppear {
            // After clipboard animation completes, show microphone icon
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                withAnimation(.easeInOut(duration: 0.5)) {
                    showMicrophoneIcon = true
                }
            }
        }
    }
}



struct ModernTranscriptionPanel: View {
    let text: String
    @State private var animateText = false
    
    var body: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(.thinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(.white.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.1), radius: 15, x: 0, y: 5)
            .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
            .overlay(
                Group {
                    if text.isEmpty {
                        // Empty state with elegant placeholder
                        VStack(spacing: 16) {
                            Image(systemName: "quote.bubble")
                                .font(.system(size: 32, weight: .light))
                                .foregroundStyle(.secondary)
                                .symbolRenderingMode(.hierarchical)
                            
                            Text("No transcription yet")
                                .font(.system(size: 12.6, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                        .transition(.opacity.combined(with: .scale))
                    } else {
                        // Transcribed text with typing animation
                        ScrollView {
                            Text(text)
                                .font(.system(size: 12.6, weight: .regular, design: .rounded))
                                .foregroundStyle(.primary)
                                .lineSpacing(4)
                                .padding(20)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }
                        .animation(.easeInOut(duration: 0.5), value: text)
                    }
                }
            )
            .frame(height: 150)
            .animation(.easeInOut(duration: 0.3), value: text.isEmpty)
    }
}

struct ModernFooterView: View {
    @ObservedObject var appState: AppStateModel
    
    var body: some View {
        if appState.settings.hotkeyEnabled {
            HStack(spacing: 12) {
                // Hotkey label with icon
                Label("Global Hotkey:", systemImage: "keyboard")
                    .font(.system(size: 12.6, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                
                // Modern hotkey display
                Text(formatHotkeyDisplay(appState.settings.hotkeyDisplay))
                    .font(.system(size: 12.6, weight: .semibold, design: .monospaced)) // match label size
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(
                        Capsule()
                            .stroke(.white.opacity(0.3), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.thinMaterial, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(.white.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 3)
            .transition(.opacity.combined(with: .scale))
        }
    }
    
    private func formatHotkeyDisplay(_ display: String) -> String {
        // Convert the display to use proper symbols
        return display
            .replacingOccurrences(of: "Cmd", with: "⌘")
            .replacingOccurrences(of: "Shift", with: "⇧")
            .replacingOccurrences(of: "Option", with: "⌥")
            .replacingOccurrences(of: "Control", with: "⌃")
            .replacingOccurrences(of: "+", with: " ")
    }
}

// MARK: - Mini Wave Visualizer for Main Window
struct MiniWaveVisualizer: View {
    let audioLevels: [Float]
    
    private let barCount = 16
    private let barSpacing: CGFloat = 1.5
    
    var body: some View {
        TimelineView(.animation) { timeline in
            let currentTime = timeline.date.timeIntervalSinceReferenceDate
            
            HStack(spacing: barSpacing) {
                ForEach(0..<barCount, id: \.self) { index in
                    MiniWaveformBar(
                        index: index,
                        barCount: barCount,
                        audioLevels: audioLevels,
                        time: currentTime
                    )
                }
            }
        }
    }
}

// MARK: - Mini Waveform Bar
struct MiniWaveformBar: View {
    let index: Int
    let barCount: Int
    let audioLevels: [Float]
    let time: Double
    
    private var barWidth: CGFloat {
        2.0
    }
    
    private var audioLevel: Float {
        // Map bar index to audio frequency band
        let audioIndex = Int(Float(index) / Float(barCount) * Float(audioLevels.count))
        if audioIndex < audioLevels.count {
            return audioLevels[audioIndex]
        }
        return 0.0
    }
    
    private var animatedHeight: CGFloat {
        let maxHeight: CGFloat = 24
        let baseHeight = CGFloat(audioLevel) * maxHeight
        let animationOffset = Darwin.sin(time * 4 + Double(index) * 0.3) * 2
        return max(2, baseHeight + animationOffset)
    }
    
    private var rainbowColor: Color {
        // Create rainbow gradient from purple to red based on bar position
        let normalizedPosition = Double(index) / Double(barCount - 1)
        
        // Rainbow progression: Purple -> Blue -> Cyan -> Green -> Yellow -> Orange -> Red
        let hue = 0.8 - (normalizedPosition * 0.8) // 0.8 (purple) to 0.0 (red)
        
        return Color(
            hue: hue,
            saturation: 0.8 + Double(audioLevel) * 0.2, // More saturated with audio
            brightness: 0.7 + Double(audioLevel) * 0.3  // Brighter with audio
        )
    }
    
    var body: some View {
        VStack {
            Spacer()
            
            RoundedRectangle(cornerRadius: barWidth / 2)
                .fill(
                    LinearGradient(
                        colors: [
                            rainbowColor.opacity(0.9),
                            rainbowColor.opacity(0.7),
                            rainbowColor.opacity(0.5)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: barWidth, height: animatedHeight)
                .shadow(color: rainbowColor.opacity(0.3), radius: 1, x: 0, y: 0.5)
                .animation(.easeOut(duration: 0.05), value: Double(audioLevel))
            
            Spacer()
        }
        .frame(height: 24)
    }
}

// MARK: - Mini Transcribing Visualizer
struct MiniTranscribingVisualizer: View {
    private let barCount = 16
    private let barSpacing: CGFloat = 1.5
    
    var body: some View {
        TimelineView(.animation) { timeline in
            let currentTime = timeline.date.timeIntervalSinceReferenceDate
            
            HStack(spacing: barSpacing) {
                ForEach(0..<barCount, id: \.self) { index in
                    MiniTranscribingBar(
                        index: index,
                        barCount: barCount,
                        time: currentTime
                    )
                }
            }
        }
    }
}

// MARK: - Mini Transcribing Bar
struct MiniTranscribingBar: View {
    let index: Int
    let barCount: Int
    let time: Double
    
    private var barWidth: CGFloat {
        2.0
    }
    
    private var animatedHeight: CGFloat {
        let maxHeight: CGFloat = 24
        let minHeight: CGFloat = 0.5
        
        // Create rolling wave pattern with more dramatic variation
        let waveOffset = time * 2
        let indexOffset = Double(index) * 0.4
        
        let primaryWave = Darwin.sin(waveOffset + indexOffset) * 0.5
        let secondaryWave = Darwin.sin(waveOffset * 1.5 + indexOffset * 0.7) * 0.4
        
        let combinedWave = primaryWave + secondaryWave
        let normalizedHeight = (combinedWave + 1) / 2 // Normalize to 0-1
        
        // Map to height range with more dramatic variation
        let heightRange = maxHeight - minHeight
        return minHeight + (normalizedHeight * heightRange)
    }
    
    private var rainbowColor: Color {
        // Create rainbow gradient from purple to red based on bar position
        let normalizedPosition = Double(index) / Double(barCount - 1)
        
        // Rainbow progression with rolling animation
        let timeOffset = time * 0.5
        let hue = fmod(0.8 - (normalizedPosition * 0.8) + timeOffset, 1.0)
        
        return Color(
            hue: hue,
            saturation: 0.8,
            brightness: 0.8
        )
    }
    
    var body: some View {
        VStack {
            Spacer()
            
            RoundedRectangle(cornerRadius: barWidth / 2)
                .fill(
                    LinearGradient(
                        colors: [
                            rainbowColor.opacity(0.9),
                            rainbowColor.opacity(0.7),
                            rainbowColor.opacity(0.5)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: barWidth, height: animatedHeight)
                .shadow(color: rainbowColor.opacity(0.3), radius: 1, x: 0, y: 0.5)
            
            Spacer()
        }
        .frame(height: 24)
    }
}

// MARK: - Mini Clipboard Visualizer
struct MiniClipboardVisualizer: View {
    @State private var showCompleted = false
    @State private var pulseScale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            if showCompleted {
                // Completed state with checkmark
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color.blue.opacity(0.8),
                                Color.cyan.opacity(0.6)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(pulseScale)
                    .shadow(color: Color.blue.opacity(0.2), radius: 2, x: 0, y: 1)
            } else {
                // Initial clipboard animation
                ZStack {
                    // Background glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.blue.opacity(0.3),
                                    Color.blue.opacity(0.1),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 12
                            )
                        )
                        .frame(width: 24, height: 24)
                        .scaleEffect(pulseScale)
                    
                    // Clipboard icon
                    Image(systemName: "clipboard")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.blue)
                        .scaleEffect(pulseScale)
                }
            }
        }
        .onAppear {
            startAnimation()
        }
    }
    
    private func startAnimation() {
        // Phase 1: Initial clipboard animation
        withAnimation(.easeInOut(duration: 0.4)) {
            pulseScale = 1.2
        }
        
        // Phase 2: Transition to completed state
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeInOut(duration: 0.3)) {
                showCompleted = true
                pulseScale = 1.0
            }
            
            // Subtle pulse for completed state
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                pulseScale = 1.05
            }
        }
    }
}

#Preview {
    ContentView(appState: AppStateModel())
} 