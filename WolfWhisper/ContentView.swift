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
            
            VStack(spacing: 20) {
                // Modern Header with Wolf Logo
                ModernHeaderView(appState: appState)
                
                // Central Recording Interface
                VStack(spacing: 12) {
                    // Glass-style Recording Button
                    ModernRecordingButton(
                        state: appState.currentState,
                        isRecording: appState.currentState == .recording,
                        audioLevels: appState.audioLevels,
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
                    
                    // Show accessibility permission button if needed
                    if appState.statusText.contains("Accessibility Access") {
                        Button(action: {
                            appState.requestAccessibilityPermission()
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "hand.raised.fill")
                                    .font(.system(size: 14, weight: .medium))
                                Text("Grant Accessibility Permission")
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(LinearGradient(
                                        gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ))
                            )
                            .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .transition(.opacity.combined(with: .scale))
                    }
                }
                
                // Modern Transcription Panel
                ModernTranscriptionPanel(text: appState.transcribedText)
                
                // Sleek Footer with Hotkey
                ModernFooterView(appState: appState)
            }
            .padding(.top, 15)
            .padding(.horizontal, 25)
            .padding(.bottom, 15)
        }
        .frame(minWidth: 450, maxWidth: 600, minHeight: 500, maxHeight: 650)
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
                .font(.system(size: 28, weight: .semibold, design: .rounded))
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
                        ModernIdleContent()
                    case .recording:
                        ModernRecordingContent(audioLevels: audioLevels)
                    case .transcribing:
                        ModernTranscribingContent()
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
            .font(.system(size: 32, weight: .medium))
            .foregroundStyle(.white)
            .symbolRenderingMode(.hierarchical)
    }
}

struct ModernRecordingContent: View {
    let audioLevels: [Float]
    @State private var waveAnimation: Bool = false
    
    var body: some View {
        ZStack {
            // Animated waveform background
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .stroke(.white.opacity(0.3), lineWidth: 2)
                    .frame(width: CGFloat(40 + index * 15), height: CGFloat(40 + index * 15))
                    .scaleEffect(waveAnimation ? 1.2 : 0.8)
                    .opacity(waveAnimation ? 0.0 : 0.6)
                    .animation(
                        .easeInOut(duration: 1.5)
                        .repeatForever(autoreverses: false)
                        .delay(Double(index) * 0.3),
                        value: waveAnimation
                    )
            }
            
            Image(systemName: "waveform")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(.white)
                .symbolRenderingMode(.hierarchical)
        }
        .onAppear {
            waveAnimation = true
        }
    }
}

struct ModernTranscribingContent: View {
    @State private var rotationAngle: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var nodeOpacity: Double = 0.5
    
    var body: some View {
        ZStack {
            // Outer ring
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [Color.cyan.opacity(0.8), Color.blue.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 3
                )
                .frame(width: 70, height: 70)
                .rotationEffect(.degrees(rotationAngle))
            
            // Middle ring
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.4)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
                .frame(width: 55, height: 55)
                .rotationEffect(.degrees(-rotationAngle * 0.7))
            
            // Inner ring
            Circle()
                .stroke(Color.purple.opacity(0.4), lineWidth: 1.5)
                .frame(width: 40, height: 40)
                .rotationEffect(.degrees(rotationAngle * 1.3))
            
            // Processing nodes
            ForEach(0..<6, id: \.self) { node in
                Circle()
                    .fill(Color.cyan)
                    .frame(width: 4, height: 4)
                    .offset(
                        x: cos(Double(node) * .pi / 3) * 25,
                        y: sin(Double(node) * .pi / 3) * 25
                    )
                    .rotationEffect(.degrees(rotationAngle * 0.5))
                    .opacity(nodeOpacity)
            }
            
            // Central brain
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white)
                    .frame(width: 28, height: 22)
                    .scaleEffect(pulseScale)
                
                Image(systemName: "brain")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.cyan)
                    .scaleEffect(pulseScale)
            }
        }
        .onAppear {
            startAnimations()
        }
    }
    
    private func startAnimations() {
        withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
            rotationAngle = 360
        }
        
        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
            pulseScale = 1.15
        }
        
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            nodeOpacity = 1.0
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
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                        .transition(.opacity.combined(with: .scale))
                    } else {
                        // Transcribed text with typing animation
                        ScrollView {
                            Text(text)
                                .font(.system(size: 16, weight: .regular, design: .rounded))
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
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                
                // Modern hotkey display
                Text(formatHotkeyDisplay(appState.settings.hotkeyDisplay))
                    .font(.system(size: 16, weight: .semibold, design: .monospaced))
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

#Preview {
    ContentView(appState: AppStateModel())
} 