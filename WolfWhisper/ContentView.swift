import SwiftUI
import AVFoundation

struct ContentView: View {
    @ObservedObject var appState: AppState
    
    var body: some View {
        MainAppView(
            appState: appState,
            onStartRecording: startRecording,
            onStopRecording: stopRecording
        )
            .onAppear {
                setupServices()
                setupHotkey()
            }
            .onChange(of: appState.hotkeyEnabled) { _ in setupHotkey() }
            .onChange(of: appState.hotkeyModifiers) { _ in setupHotkey() }
            .onChange(of: appState.hotkeyKey) { _ in setupHotkey() }
    }
    
    private func setupServices() {
        // Set up audio service callbacks
        AudioService.shared.onStateChange = { state in
            appState.updateState(to: state)
        }
        
        AudioService.shared.onAudioLevelsUpdate = { levels in
            appState.updateAudioLevels(levels)
        }
        
        // Set up hotkey callback
        HotkeyService.shared.onHotkeyPressed = {
            handleHotkeyPressed()
        }
    }
    
    private func setupHotkey() {
        if appState.hotkeyEnabled {
            HotkeyService.shared.registerHotkey(
                modifiers: appState.hotkeyModifiers,
                key: appState.hotkeyKey
            )
        } else {
            HotkeyService.shared.unregisterHotkey()
        }
    }
    
    private func handleHotkeyPressed() {
        switch appState.currentState {
        case .idle:
            startRecording()
        case .recording:
            stopRecording()
        case .transcribing:
            break
        }
    }
    
    private func startRecording() {
        appState.debugInfo = "Debug: Starting recording..."
        guard appState.isConfigured() else {
            appState.debugInfo = "Debug: Settings not configured"
            appState.showSettings = true
            return
        }
        
        Task {
            do {
                try await AudioService.shared.startRecording()
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
                await MainActor.run { appState.updateState(to: .transcribing) }
                
                let audioData = try await AudioService.shared.stopRecording()
                appState.debugInfo = "Debug: Got \(audioData.count) bytes, transcribing..."
                
                // Get transcription settings from appState on the main actor
                let (provider, apiKey, model) = await MainActor.run {
                    let provider = appState.selectedProvider
                    let apiKey: String
                    let model: String
                    switch provider {
                    case .openAI:
                        apiKey = appState.openAIAPIKey
                        model = appState.selectedOpenAIModel
                    case .gemini:
                        apiKey = appState.geminiAPIKey
                        model = appState.selectedGeminiModel
                    }
                    return (provider, apiKey, model)
                }

                let transcribedText = try await CombinedTranscriptionService.shared.transcribe(
                    audioData: audioData,
                    provider: provider,
                    apiKey: apiKey,
                    model: model
                )
                
                appState.debugInfo = "Debug: Got transcription: '\(transcribedText)'"
                
                await MainActor.run {
                    appState.transcribedText = transcribedText
                }
                
                HotkeyService.shared.copyToClipboard(transcribedText)
                
                // Short delay before pasting
                try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
                HotkeyService.shared.pasteToActiveWindow()
                
                await MainActor.run { appState.updateState(to: .idle) }
                
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
    @ObservedObject var appState: AppState
    var onStartRecording: () -> Void
    var onStopRecording: () -> Void
    
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
                        audioLevels: appState.audioLevelHistory,
                        action: {
                            handleRecordingButtonTap()
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
                ModernTranscriptionPanel(text: appState.transcribedText, appState: appState)
                
                // Sleek Footer with Hotkey
                ModernFooterView(appState: appState)
            }
            .padding(.top, 15)
            .padding(.horizontal, 25)
            .padding(.bottom, 15)
        }
        .frame(minWidth: 450, maxWidth: 600, minHeight: 500, maxHeight: 650)
    }

    private func handleRecordingButtonTap() {
        switch appState.currentState {
        case .idle:
            onStartRecording()
        case .recording:
            onStopRecording()
        case .transcribing:
            // Do nothing
            break
        }
    }
}

struct ModernHeaderView: View {
    @ObservedObject var appState: AppState
    
    private var providerAndModelDisplay: String {
        // Ensure we're showing the current provider and model
        let provider = appState.selectedProvider
        let isConfigured = appState.isConfigured()
        
        switch provider {
        case .openAI:
            let model = appState.selectedOpenAIModel
            return isConfigured ? "Ready: OpenAI \(model)" : "Setup: OpenAI \(model)"
        case .gemini:
            let model = appState.selectedGeminiModel
            return isConfigured ? "Ready: Gemini \(model)" : "Setup: Gemini \(model)"
        }
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            // Modern Wolf Logo
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 50, height: 50)
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
                
                Image(systemName: "pawprint.circle.fill")
                    .resizable()
                    .frame(width: 32, height: 32)
                    .foregroundStyle(.primary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                // App Title with Modern Typography
                Text("WolfWhisper")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                
                // Provider and Model Display
                Text(providerAndModelDisplay)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(
                        Capsule()
                            .stroke(.white.opacity(0.2), lineWidth: 1)
                    )
            }
            
            Spacer()
        }
        .padding(.horizontal, 4)
        .onAppear {
            // Force a refresh of the display when the view appears
            // This ensures the provider display shows the correct information immediately
        }
        .onChange(of: appState.selectedProvider) { _, _ in
            // Force UI update when provider changes
        }
        .onChange(of: appState.selectedOpenAIModel) { _, _ in
            // Force UI update when OpenAI model changes
        }
        .onChange(of: appState.selectedGeminiModel) { _, _ in
            // Force UI update when Gemini model changes
        }
    }
}



struct ModernRecordingButton: View {
    let state: AppStateValue
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
    
    var body: some View {
        ZStack {
            Image(systemName: "text.quote")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(.white)
                .symbolRenderingMode(.hierarchical)
                .rotationEffect(.degrees(rotationAngle))
                .onAppear {
                    withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                        rotationAngle = 360
                    }
                }
        }
    }
}

struct ModernTranscriptionPanel: View {
    let text: String
    @ObservedObject var appState: AppState
    @State private var animateText = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Main transcription content
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
    

}

struct ModernFooterView: View {
    @ObservedObject var appState: AppState
    
    var body: some View {
        if appState.hotkeyEnabled {
            HStack(spacing: 12) {
                // Hotkey label with icon
                HStack(spacing: 6) {
                    Image(systemName: "keyboard.fill")
                        .font(.system(size: 16, weight: .medium))
                    Text("HOTKEY")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
                .foregroundStyle(.secondary)
                
                // Modern hotkey display
                Text(appState.hotkeyDisplay)
                    .font(.system(size: 16, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(.primary.opacity(0.1))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(.primary.opacity(0.2), lineWidth: 1)
                    )
            }
        }
    }
}

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(appState: AppState())
    }
}
#endif 