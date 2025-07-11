import SwiftUI
import AVFoundation

struct ContentView: View {
    @ObservedObject var appState: AppStateModel
    @StateObject private var audioService = AudioService.shared
    @StateObject private var transcriptionService = TranscriptionService.shared
    @StateObject private var hotkeyService = HotkeyService.shared
    @State private var isWindowVisible = true
    
    var body: some View {
        MainAppView(appState: appState, isWindowVisible: isWindowVisible)
        .onAppear {
            setupServices()
            setupHotkey()
        }
        .onDisappear {
            // CRITICAL FIX: Clear callbacks to break retain cycles and allow the view to deallocate.
            audioService.onStateChange = nil
            audioService.onAudioLevelsUpdate = nil
            transcriptionService.onTranscriptionComplete = nil
            hotkeyService.onHotkeyPressed = nil
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            isWindowVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { _ in
            isWindowVisible = false
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
        audioService.onStateChange = { [weak appState] state in
            appState?.updateState(to: state)
        }
        
        audioService.onAudioLevelsUpdate = { [weak appState] levels in
            appState?.updateAudioLevels(levels)
        }
        
        // Set up transcription service callback, capturing state objects weakly to prevent retain cycles.
        transcriptionService.onTranscriptionComplete = { [weak appState, weak hotkeyService] result in
            guard let appState = appState else { return }
            Task { @MainActor in
                switch result {
                case .success(let text):
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    var isNonsense = false
                    
                    if trimmed.count >= 8 {
                        let chars = Array(trimmed)
                        let repeated = chars[1]
                        if chars[1...7].allSatisfy({ $0 == repeated }) {
                            isNonsense = true
                        }
                    }
                    
                    if trimmed.isEmpty || isNonsense {
                        appState.lastTranscriptionSuccessful = false
                        appState.transcribedText = "No speech detected"
                        appState.updateState(to: .idle, message: "No speech detected")
                    } else {
                        appState.lastTranscriptionSuccessful = true
                        appState.transcribedText = text
                        appState.updateState(to: .idle)
                        
                        let pasteboard = NSPasteboard.general
                        pasteboard.clearContents()
                        pasteboard.setString(text, forType: .string)
                        
                        if appState.wasRecordingStartedByHotkey {
                            hotkeyService?.setTextToPaste(text)
                            hotkeyService?.pasteToActiveWindow()
                        }
                    }
                case .failure(let error):
                    appState.lastTranscriptionSuccessful = false
                    appState.updateState(to: .idle, message: "Error: \(error.localizedDescription)")
                }
                
                appState.wasRecordingStartedByHotkey = false
            }
        }
        
        // Set up hotkey callback, moving logic inside and capturing weakly to prevent retain cycles.
        hotkeyService.onHotkeyPressed = { [weak appState, weak audioService, weak transcriptionService] in
            guard let appState = appState else { return }
            appState.wasRecordingStartedByHotkey = true
            
            if appState.currentState == .idle {
                appState.lastTranscriptionSuccessful = false
                guard appState.settings.isConfigured else {
                    appState.showSettings = true
                    return
                }
                Task {
                    do {
                        try await audioService?.startRecording()
                    } catch {
                        await MainActor.run {
                            appState.updateState(to: .idle, message: "Recording failed: \(error.localizedDescription)")
                        }
                    }
                }
            } else if appState.currentState == .recording {
                Task {
                    do {
                        guard let audioService = audioService,
                              let transcriptionService = transcriptionService else { return }
                        let audioData = try await audioService.stopRecording()
                        
                        await MainActor.run {
                            appState.updateState(to: .transcribing)
                        }
                        
                        try await transcriptionService.transcribe(
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
            }
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
}

struct MainAppView: View {
    @ObservedObject var appState: AppStateModel
    let isWindowVisible: Bool
    
    var body: some View {
        ZStack {
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
            
            VStack(spacing: 10) {
                ModernHeaderView(appState: appState)
                
                VStack(spacing: 6) {
                    ModernRecordingButton(
                        state: appState.currentState,
                        isRecording: appState.currentState == .recording,
                        audioLevels: appState.audioLevels,
                        appState: appState,
                        action: {
                            handleRecordingButtonTap(appState: appState)
                        }
                    )
                    
                    Text(appState.statusText)
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundStyle(.primary)
                        // .transition(.opacity.combined(with: .scale))
                        // .animation(.easeInOut(duration: 0.3), value: appState.statusText)
                }
                
                ModernTranscriptionPanel(text: appState.transcribedText)
                
                ModernFooterView(appState: appState)
            }
            .padding(.top, 4)
            .padding(.horizontal, 17.5)
            .padding(.bottom, 10.5)
        }
        .frame(width: 380, height: 420)
    }
}

struct ModernHeaderView: View {
    @ObservedObject var appState: AppStateModel
    
    var body: some View {
        HStack(alignment: .center, spacing: 16) {
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
            
            Text("WolfWhisper")
                .font(.system(size: 19.6, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            
            Spacer()
        }
        .padding(.horizontal, 4)
    }
}

@MainActor
private func handleRecordingButtonTap(appState: AppStateModel) {
    switch appState.currentState {
    case .idle:
        guard appState.settings.isConfigured else {
            appState.showSettings = true
            return
        }
        
        appState.wasTriggeredByHotkey = false
        appState.wasRecordingStartedByHotkey = false
        appState.lastTranscriptionSuccessful = false
        
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
        Task {
            do {
                let audioData = try await AudioService.shared.stopRecording()
                
                await MainActor.run {
                    appState.updateState(to: .transcribing)
                }
                
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
        break
    }
}

struct ModernRecordingButton: View {
    let state: AppState
    let isRecording: Bool
    let audioLevels: [Float]
    @ObservedObject var appState: AppStateModel
    let action: () -> Void

    var body: some View {
        ZStack {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 100, height: 100)
                    .overlay(
                        Circle()
                            .stroke(.white.opacity(0.3), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
                    .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)

                Group {
                    switch state {
                    case .idle:
                        if appState.transcribedText.isEmpty {
                            ModernIdleContent()
                        } else {
                            ModernCompletedContent()
                        }
                    case .recording:
                        ModernRecordingContent(audioLevels: audioLevels, appState: appState, isWindowVisible: true)
                    case .transcribing:
                        ModernTranscribingContentNew(appState: appState, isWindowVisible: true)
                    }
                }
            }
        }
        .onTapGesture {
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
            action()
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
    let isWindowVisible: Bool
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.1))
                .frame(width: 70, height: 70)
            if appState.currentState == .recording && isWindowVisible {
                MiniWaveVisualizer(audioLevels: audioLevels, isActive: true)
            } else {
                MiniWaveVisualizer(audioLevels: audioLevels, isActive: false)
            }
        }
    }
}

struct ModernTranscribingContentNew: View {
    @ObservedObject var appState: AppStateModel
    let isWindowVisible: Bool
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 70, height: 70)
                MiniTranscribingVisualizer(isActive: appState.currentState == .transcribing && isWindowVisible)
            }
            Text("Transcribing... The result will be copied to your clipboard.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 2)
        }
    }
}

struct ModernTranscriptionPanel: View {
    let text: String
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
                        VStack(spacing: 16) {
                            Image(systemName: "quote.bubble")
                                .font(.system(size: 32, weight: .light))
                                .foregroundStyle(.secondary)
                                .symbolRenderingMode(.hierarchical)
                            Text("No transcription yet")
                                .font(.system(size: 12.6, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        ScrollView {
                            Text(text)
                                .font(.system(size: 12.6, weight: .regular, design: .rounded))
                                .foregroundStyle(.primary)
                                .lineSpacing(4)
                                .padding(20)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            )
            .frame(height: 150)
    }
}

struct ModernFooterView: View {
    @ObservedObject var appState: AppStateModel
    
    var body: some View {
        if appState.settings.hotkeyEnabled {
            HStack(spacing: 12) {
                Label("Global Hotkey:", systemImage: "keyboard")
                    .font(.system(size: 12.6, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                
                Text(formatHotkeyDisplay(appState.settings.hotkeyDisplay))
                    .font(.system(size: 12.6, weight: .semibold, design: .monospaced))
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
            // .transition(.opacity.combined(with: .scale))
        }
    }
    
    private func formatHotkeyDisplay(_ display: String) -> String {
        return display
            .replacingOccurrences(of: "Cmd", with: "⌘")
            .replacingOccurrences(of: "Shift", with: "⇧")
            .replacingOccurrences(of: "Option", with: "⌥")
            .replacingOccurrences(of: "Control", with: "⌃")
            .replacingOccurrences(of: "+", with: " ")
    }
}

struct ModernCompletedContent: View {
    @State private var showMicrophoneIcon = false
    @State private var animationTask: DispatchWorkItem?
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.1))
                .frame(width: 70, height: 70)
            if showMicrophoneIcon {
                Image(systemName: "mic.fill")
                    .font(.system(size: 33.6, weight: .medium))
                    .foregroundStyle(.white)
                    .symbolRenderingMode(.hierarchical)
                    .transition(.opacity.combined(with: .scale))
            } else {
                MiniClipboardVisualizer()
                    .scaleEffect(2.5)
            }
        }
        .onAppear(perform: setupAnimations)
        .onDisappear(perform: cancelAnimations)
    }
    private func setupAnimations() {
        showMicrophoneIcon = false
        let task = DispatchWorkItem {
            withAnimation(.easeInOut(duration: 0.5)) {
                self.showMicrophoneIcon = true
            }
        }
        self.animationTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: task)
    }
    private func cancelAnimations() {
        animationTask?.cancel()
    }
}

struct MiniWaveVisualizer: View {
    let audioLevels: [Float]
    let isActive: Bool
    private let barCount = 16
    private let barSpacing: CGFloat = 1.5
    var body: some View {
        if isActive {
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
        } else {
            HStack(spacing: barSpacing) {
                ForEach(0..<barCount, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 2, height: 2)
                }
            }
        }
    }
}

struct MiniWaveformBar: View {
    let index: Int
    let barCount: Int
    let audioLevels: [Float]
    let time: Double
    
    private var barWidth: CGFloat {
        2.0
    }
    
    private var audioLevel: Float {
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
        let normalizedPosition = Double(index) / Double(barCount - 1)
        let hue = 0.8 - (normalizedPosition * 0.8)
        
        return Color(
            hue: hue,
            saturation: 0.8 + Double(audioLevel) * 0.2,
            brightness: 0.7 + Double(audioLevel) * 0.3
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
                // .animation(.easeOut(duration: 0.05), value: Double(audioLevel))
            
            Spacer()
        }
        .frame(height: 24)
    }
}

struct MiniTranscribingVisualizer: View {
    let isActive: Bool
    private let barCount = 16
    private let barSpacing: CGFloat = 1.5
    var body: some View {
        if isActive {
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
        } else {
            HStack(spacing: barSpacing) {
                ForEach(0..<barCount, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 2, height: 2)
                }
            }
        }
    }
}

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
        
        let waveOffset = time * 2
        let indexOffset = Double(index) * 0.4
        
        let primaryWave = Darwin.sin(waveOffset + indexOffset) * 0.5
        let secondaryWave = Darwin.sin(waveOffset * 1.5 + indexOffset * 0.7) * 0.4
        
        let combinedWave = primaryWave + secondaryWave
        let normalizedHeight = (combinedWave + 1) / 2
        
        let heightRange = maxHeight - minHeight
        return minHeight + (normalizedHeight * heightRange)
    }
    
    private var rainbowColor: Color {
        let normalizedPosition = Double(index) / Double(barCount - 1)
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

struct MiniClipboardVisualizer: View {
    @State private var showCompleted = false
    @State private var pulseScale: CGFloat = 1.0
    @State private var animationTask: DispatchWorkItem?

    var body: some View {
        ZStack {
            if showCompleted {
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
                ZStack {
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
                    
                    Image(systemName: "clipboard")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.blue)
                        .scaleEffect(pulseScale)
                }
            }
        }
        .onAppear(perform: startAnimation)
        .onDisappear(perform: cancelAnimation)
    }
    
    private func startAnimation() {
        withAnimation(.easeInOut(duration: 0.4)) {
            pulseScale = 1.2
        }
        let task = DispatchWorkItem {
            withAnimation(.easeInOut(duration: 0.3)) {
                self.showCompleted = true
                self.pulseScale = 1.0
            }
        }
        self.animationTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: task)
    }
    
    private func cancelAnimation() {
        animationTask?.cancel()
    }
}

#Preview {
    ContentView(appState: AppStateModel())
} 