import SwiftUI
import Foundation

// MARK: - 3D Particle Data Structure for Wave Visualizer
struct WaveParticle {
    var position: SIMD3<Float> // 3D position (x, y, z)
    var basePosition: SIMD2<Float> // Original grid position (x, z)
    var baseColor: Color
    var size: Float
    var gridIndex: Int
    
    init(gridX: Int, gridZ: Int, totalGridWidth: Int, totalGridDepth: Int, bounds: CGRect) {
        let spacing: Float = 8.0
        let centerX = Float(bounds.midX)
        
        let x = centerX + (Float(gridX) - Float(totalGridWidth) / 2.0) * spacing
        let z = (Float(gridZ) - Float(totalGridDepth) / 2.0) * spacing
        
        self.basePosition = SIMD2<Float>(x, z)
        self.position = SIMD3<Float>(x, 0, z)
        self.size = Float.random(in: 1.5...3.0)
        self.gridIndex = gridX + gridZ * totalGridWidth
        
        // Opalescent color palette based on position
        let colorIndex = (gridX + gridZ) % 4
        switch colorIndex {
        case 0: self.baseColor = Color(hue: 0.8, saturation: 0.8, brightness: 0.9) // Magenta
        case 1: self.baseColor = Color(hue: 0.5, saturation: 0.9, brightness: 0.95) // Cyan
        case 2: self.baseColor = Color(hue: 0.1, saturation: 0.7, brightness: 1.0) // Gold
        default: self.baseColor = Color(hue: 0.7, saturation: 0.6, brightness: 0.8) // Indigo
        }
    }
}

// MARK: - Enhanced Perlin Noise for Organic Wave Movement
struct EnhancedNoiseField {
    private let permutation: [Int]
    
    init() {
        var p = Array(0..<256)
        p.shuffle()
        self.permutation = p + p
    }
    
    func noise3D(x: Float, y: Float, z: Float) -> Float {
        let xi = Int(floor(x)) & 255
        let yi = Int(floor(y)) & 255
        let zi = Int(floor(z)) & 255
        
        let xf = x - floor(x)
        let yf = y - floor(y)
        let zf = z - floor(z)
        
        let u = fade(xf)
        let v = fade(yf)
        let w = fade(zf)
        
        let a = permutation[xi] + yi
        let b = permutation[xi + 1] + yi
        let aa = permutation[a] + zi
        let ab = permutation[a + 1] + zi
        let ba = permutation[b] + zi
        let bb = permutation[b + 1] + zi
        
        return lerp(w,
            lerp(v,
                lerp(u, grad(permutation[aa], xf, yf, zf),
                       grad(permutation[ba], xf - 1, yf, zf)),
                lerp(u, grad(permutation[ab], xf, yf - 1, zf),
                       grad(permutation[bb], xf - 1, yf - 1, zf))),
            lerp(v,
                lerp(u, grad(permutation[aa + 1], xf, yf, zf - 1),
                       grad(permutation[ba + 1], xf - 1, yf, zf - 1)),
                lerp(u, grad(permutation[ab + 1], xf, yf - 1, zf - 1),
                       grad(permutation[bb + 1], xf - 1, yf - 1, zf - 1))))
    }
    
    private func fade(_ t: Float) -> Float {
        return t * t * t * (t * (t * 6 - 15) + 10)
    }
    
    private func lerp(_ t: Float, _ a: Float, _ b: Float) -> Float {
        return a + t * (b - a)
    }
    
    private func grad(_ hash: Int, _ x: Float, _ y: Float, _ z: Float) -> Float {
        let h = hash & 15
        let u = h < 8 ? x : y
        let v = h < 4 ? y : (h == 12 || h == 14 ? x : z)
        return ((h & 1) == 0 ? u : -u) + ((h & 2) == 0 ? v : -v)
    }
}

struct FloatingRecordingView: View {
    @ObservedObject var appState: AppStateModel
    @State private var shouldFadeOut = false
    @State private var clipboardState: ClipboardState = .none
    @Environment(\.controlActiveState) private var controlActiveState
    
    enum ClipboardState {
        case none
        case copyingToClipboard
        case copyingToClipboardAndPasting
    }
    
    var body: some View {
        ZStack {
            // Match main app/settings gradient background
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.4, green: 0.6, blue: 0.8).opacity(0.3),
                            Color(red: 0.8, green: 0.6, blue: 0.4).opacity(0.3),
                            Color(red: 0.5, green: 0.8, blue: 0.6).opacity(0.3)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            // Overlay glass morphism effect
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(.ultraThinMaterial)
                .opacity(0.8)
            // Glass border with subtle glow
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.6),
                            Color.white.opacity(0.3),
                            Color.white.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
            .shadow(color: Color.black.opacity(0.3), radius: 30, x: 0, y: 12)
            .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
            .shadow(color: Color.white.opacity(0.1), radius: 1, x: 0, y: 1)
            
            // Content layout
            VStack(spacing: 20) {
                // Waveform at top with padding for max height
                VStack(spacing: 0) {
                    Spacer(minLength: 10) // Top padding
                    
                    if controlActiveState == .key && appState.currentState == .recording {
                        TimelineView(.animation) { timeline in
                            DataWaveVisualizer(audioLevels: appState.audioLevels)
                                .frame(height: 60)
                        }
                    } else if appState.currentState == .recording {
                        DataWaveVisualizer(audioLevels: appState.audioLevels)
                            .frame(height: 60)
                        } else if appState.currentState == .transcribing {
                        if controlActiveState == .key {
                            TimelineView(.animation) { timeline in
                                TranscribingWaveVisualizer()
                                    .frame(height: 60)
                            }
                        } else {
                            TranscribingWaveVisualizer()
                                .frame(height: 60)
                        }
                    } else if appState.currentState == .idle && (clipboardState == .copyingToClipboard || clipboardState == .copyingToClipboardAndPasting) {
                        // Clipboard icon for copying states
                        ClipboardIconView(isForPasting: clipboardState == .copyingToClipboardAndPasting)
                            .frame(height: 60)
                    }
                    
                    Spacer(minLength: 10) // Bottom padding
                }
                .frame(maxHeight: 80)
                
                // Status text in middle
                VStack(spacing: 8) {
                    Text(statusText)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .transition(.opacity.combined(with: .scale))
                    
                    Text(subStatusText)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .transition(.opacity.combined(with: .scale))
                }
                .frame(minHeight: 50)
                
                // Action button at bottom
                if shouldShowButton {
                    Button(action: buttonAction) {
                        HStack(spacing: 8) {
                            Image(systemName: buttonIcon)
                                .font(.system(size: 16, weight: .bold))
                            Text(buttonText)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(buttonBackgroundColor)
                        .foregroundColor(buttonForegroundColor)
                        .cornerRadius(16)
                        .shadow(color: buttonShadowColor, radius: 4, x: 0, y: 2)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .transition(.opacity.combined(with: .scale))
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
        }
        .frame(width: 360, height: 240)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .opacity(shouldFadeOut ? 0.0 : 1.0)
        .scaleEffect(shouldFadeOut ? 0.9 : 1.0)
        .animation(.easeInOut(duration: 0.4), value: shouldFadeOut)
        .animation(.easeInOut(duration: 0.3), value: appState.currentState)
        .animation(.easeInOut(duration: 0.3), value: clipboardState)
        .onChange(of: appState.currentState) { _, newState in
            handleStateChange(newState)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.3)) {
                // Entrance animation
            }
        }
        .onDisappear {
            // No animation state variables in scope for this view
        }
    }
    
    private var statusText: String {
        switch appState.currentState {
        case .recording:
            return "Recording"
        case .transcribing:
            return "Transcribing"
        case .idle:
            switch clipboardState {
            case .copyingToClipboard:
                return "Copying to Clipboard"
            case .copyingToClipboardAndPasting:
                return "Copying to Clipboard and Pasting"
            default:
                return "Complete!"
            }
        }
    }
    
    private var subStatusText: String {
        switch appState.currentState {
        case .recording:
            return "Press hotkey again to stop or use the button below"
        case .transcribing:
            return "Transcribing your audio..."
        case .idle:
            switch clipboardState {
            case .copyingToClipboard:
                return "Text will be available in clipboard"
            case .copyingToClipboardAndPasting:
                return "Text will be pasted to active window"
            default:
                return "Transcription complete"
            }
        }
    }
    
    private var shouldShowButton: Bool {
        appState.currentState == .recording
    }
    
    private var buttonText: String {
        "Stop Recording"
    }
    
    private var buttonIcon: String {
        "stop.circle.fill"
    }
    
    private var buttonBackgroundColor: Color {
        Color.red.opacity(0.2)
    }
    
    private var buttonForegroundColor: Color {
        .red
    }
    
    private var buttonShadowColor: Color {
        .red.opacity(0.15)
    }
    
    private func buttonAction() {
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
    }
    
    private func handleStateChange(_ newState: AppState) {
        switch newState {
        case .recording, .transcribing:
            // CRITICAL FIX: Reset the local state when a new cycle begins.
            // This removes the old ClipboardAnimationView.
            clipboardState = .none
            shouldFadeOut = false
            
        case .idle:
            // This logic is already correct.
            if clipboardState == .none {
                if appState.lastTranscriptionSuccessful {
                    // Show clipboard animation on success
                    if appState.wasRecordingStartedByHotkey {
                        clipboardState = .copyingToClipboardAndPasting
                    } else {
                        clipboardState = .copyingToClipboard
                    }
                    
                    // After a delay, fade out and close
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            shouldFadeOut = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            NotificationCenter.default.post(name: NSNotification.Name("CloseFloatingWindow"), object: nil)
                        }
                    }
                } else {
                    // On failure, close immediately
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        NotificationCenter.default.post(name: NSNotification.Name("CloseFloatingWindow"), object: nil)
                    }
                }
            }
        }
    }
}

// MARK: - Recording State View with Data Wave Visualizer
struct RecordingStateView: View {
    let audioLevels: [Float]
    @EnvironmentObject var appState: AppStateModel
    
    var body: some View {
        VStack(spacing: 16) {
            // Data Wave Visualizer
            DataWaveVisualizer(audioLevels: audioLevels)
                .frame(height: 40)
            
            VStack(spacing: 5) {
                // Status text with animated ellipsis
                HStack(spacing: 0) {
                    Text("Recording")
                        .font(.system(size: 11.2, weight: .medium))
                        .foregroundStyle(.primary)
                    AnimatedEllipsis()
                }
                // Instructional text
                Text("Press hotkey again to stop or use the button below")
                    .font(.system(size: 5.4))
                    .foregroundStyle(.secondary)
            }
            // Stop Recording Button
            Button(action: {
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
            }) {
                HStack {
                    Image(systemName: "stop.circle.fill")
                        .font(.system(size: 15, weight: .bold))
                    Text("Stop Recording")
                        .font(.system(size: 12.6, weight: .semibold, design: .rounded))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.red.opacity(0.15))
                .foregroundColor(.red)
                .cornerRadius(8)
                .shadow(color: .red.opacity(0.08), radius: 4, x: 0, y: 1)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}

// MARK: - Transcribing Wave Visualizer
struct TranscribingWaveVisualizer: View {
    private let barCount = 32
    private let barSpacing: CGFloat = 2
    private let visualizerWidth: CGFloat = 160
    private let visualizerHeight: CGFloat = 80
    
    var body: some View {
        TimelineView(.animation) { timeline in
            let currentTime = timeline.date.timeIntervalSinceReferenceDate
            
            HStack(spacing: barSpacing) {
                ForEach(0..<barCount, id: \.self) { index in
                    TranscribingWaveBar(
                        index: index,
                        barCount: barCount,
                        time: currentTime,
                        maxHeight: visualizerHeight
                    )
                }
            }
            .frame(width: visualizerWidth, height: visualizerHeight)
        }
        .onAppear {
            // No setup needed
        }
        .onDisappear {
            // No cleanup needed
        }
    }
}

// MARK: - Transcribing Wave Bar
struct TranscribingWaveBar: View {
    let index: Int
    let barCount: Int
    let time: Double
    let maxHeight: CGFloat
    
    private var barWidth: CGFloat {
        160 / CGFloat(barCount) - 2
    }
    
    private var animatedHeight: CGFloat {
        // Create a rolling wave pattern that continuously moves
        let waveSpeed = 2.0
        let waveFrequency = 0.4
        let waveAmplitude = 0.6
        
        let baseWave = Darwin.sin(time * waveSpeed + Double(index) * waveFrequency) * waveAmplitude
        let secondaryWave = Darwin.sin(time * waveSpeed * 1.3 + Double(index) * waveFrequency * 0.7) * 0.3
        
        let normalizedLevel = (baseWave + secondaryWave + 1.0) / 2.0 // Normalize to 0-1
        let height = CGFloat(normalizedLevel) * maxHeight * 0.8 + maxHeight * 0.2
        
        return max(4, height)
    }
    
    private var rainbowColor: Color {
        // Create animated rainbow that flows with the wave
        let normalizedPosition = Double(index) / Double(barCount - 1)
        let timeOffset = time * 0.3 // Slow color flow
        
        // Rainbow progression with time-based animation
        let hue = (0.8 - (normalizedPosition * 0.8) + timeOffset).truncatingRemainder(dividingBy: 1.0)
        
        return Color(
            hue: hue,
            saturation: 0.85,
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
                .shadow(color: rainbowColor.opacity(0.4), radius: 2, x: 0, y: 1)
            
            Spacer()
        }
        .frame(height: maxHeight)
    }
}

// MARK: - Clipboard Animation View
struct ClipboardAnimationView: View {
    @State private var pulseScale: CGFloat = 1.0
    @State private var glowOpacity: Double = 0.0
    @State private var checkmarkScale: CGFloat = 0.0
    @State private var checkmarkOpacity: Double = 0.0
    @State private var sparkleAngles: [Double] = []
    @State private var sparkleScales: [CGFloat] = []
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Background circle with pulse animation
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.cyan.opacity(0.3),
                            Color.blue.opacity(0.2),
                            Color.blue.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 80, height: 80)
                .scaleEffect(pulseScale)
                .opacity(glowOpacity)
                .blur(radius: 2)
                .animation(isAnimating ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true) : .default, value: pulseScale)
            
            // Main clipboard icon
            ZStack {
                // Clipboard background
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.9))
                    .frame(width: 32, height: 40)
                    .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                
                // Clipboard clip
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.gray.opacity(0.7))
                    .frame(width: 14, height: 6)
                    .offset(y: -17)
                
                // Document lines
                VStack(spacing: 3) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.4))
                        .frame(width: 20, height: 2)
                    Rectangle()
                        .fill(Color.gray.opacity(0.4))
                        .frame(width: 16, height: 2)
                    Rectangle()
                        .fill(Color.gray.opacity(0.4))
                        .frame(width: 18, height: 2)
                }
                .offset(y: 2)
                
                // Checkmark overlay
                Image(systemName: "checkmark")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.blue)
                    .scaleEffect(checkmarkScale)
                    .opacity(checkmarkOpacity)
                    .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 0)
            }
            
            // Sparkles around the clipboard
            ForEach(0..<8, id: \.self) { index in
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.yellow)
                    .scaleEffect(sparkleScales.count > index ? sparkleScales[index] : 0.0)
                    .offset(
                        x: cos(sparkleAngles.count > index ? sparkleAngles[index] : 0) * 45,
                        y: sin(sparkleAngles.count > index ? sparkleAngles[index] : 0) * 45
                    )
                    .opacity(sparkleScales.count > index ? Double(sparkleScales[index]) : 0.0)
            }
        }
        .onAppear {
            isAnimating = true
            startClipboardAnimation()
        }
        .onDisappear {
            isAnimating = false
            pulseScale = 1.0
            glowOpacity = 0.0
            checkmarkScale = 0.0
            checkmarkOpacity = 0.0
        }
    }
    
    private func startClipboardAnimation() {
        // Initialize sparkle positions
        sparkleAngles = (0..<8).map { Double($0) * .pi / 4 }
        sparkleScales = Array(repeating: 0.0, count: 8)
        
        // Set target values for pulse animation (the .animation modifier will handle the repeat)
        pulseScale = 1.2
        glowOpacity = 0.6
        
        // Delayed checkmark appearance
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6, blendDuration: 0)) {
                checkmarkScale = 1.0
                checkmarkOpacity = 1.0
            }
        }
        
        // Sparkle animation
        for i in 0..<8 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.1) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7, blendDuration: 0)) {
                    sparkleScales[i] = 1.0
                }
                
                // Fade out sparkles
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    withAnimation(.easeOut(duration: 0.4)) {
                        sparkleScales[i] = 0.0
                    }
                }
            }
        }
    }
}

// MARK: - Data Wave Visualizer
struct DataWaveVisualizer: View {
    let audioLevels: [Float]
    
    private let barCount = 32
    private let barSpacing: CGFloat = 2
    private let visualizerWidth: CGFloat = 160
    private let visualizerHeight: CGFloat = 80
    
    var body: some View {
        TimelineView(.animation) { timeline in
            let currentTime = timeline.date.timeIntervalSinceReferenceDate
            
            HStack(spacing: barSpacing) {
                ForEach(0..<barCount, id: \.self) { index in
                    AudioWaveformBar(
                        index: index,
                        barCount: barCount,
                        audioLevels: audioLevels,
                        time: currentTime,
                        maxHeight: visualizerHeight
                    )
                }
            }
            .frame(width: visualizerWidth, height: visualizerHeight)
        }
    }
}

// MARK: - Individual Waveform Bar
struct AudioWaveformBar: View {
    let index: Int
    let barCount: Int
    let audioLevels: [Float]
    let time: Double
    let maxHeight: CGFloat
    
    private var barWidth: CGFloat {
        160 / CGFloat(barCount) - 2
    }
    
    private var audioLevel: Float {
        // Map bar index to audio frequency band
        if audioLevels.isEmpty {
            // Generate some animation when no audio levels are available
            let baseLevel = Float(Darwin.sin(time * 2 + Double(index) * 0.3)) * 0.3 + 0.4
            return max(0.1, baseLevel)
        }
        
        let audioIndex = Int(Float(index) / Float(barCount) * Float(audioLevels.count))
        if audioIndex < audioLevels.count {
            let level = audioLevels[audioIndex]
            // Ensure minimum level for visual feedback
            return max(0.1, level)
        }
        return 0.1
    }
    
    private var animatedHeight: CGFloat {
        let baseHeight = CGFloat(audioLevel) * maxHeight
        let animationOffset = Darwin.sin(time * 3 + Double(index) * 0.2) * 3
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
                .shadow(color: rainbowColor.opacity(0.3), radius: 2, x: 0, y: 1)
                .animation(.easeOut(duration: 0.05), value: Double(audioLevel))
            
            Spacer()
        }
        .frame(height: maxHeight)
    }
}

// MARK: - Transcribing State View
struct TranscribingStateView: View {
    var body: some View {
        VStack(spacing: 24) {
            // Beautiful rolling waveform for transcribing
            TranscribingWaveVisualizer()
            
            VStack(spacing: 8) {
                Text("Transcribing")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.primary)
                
                Text("Transcribing your audio...")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Completed State View
struct CompletedStateView: View {
    var body: some View {
        VStack(spacing: 24) {
            // Success indicator
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "checkmark")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(.white)
            }
            
            VStack(spacing: 8) {
                Text("Complete!")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.primary)
                
                Text("Text copied to clipboard")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Processing Indicator
struct ProcessingIndicator: View {
    @State private var pulseScale: CGFloat = 1.0
    @State private var glowOpacity: Double = 0.0
    @State private var rotationAngle: Double = 0.0
    @State private var nodeOpacity: Double = 0.0
    @State private var isAnimating = false
    
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
                    lineWidth: 4
                )
                .frame(width: 100, height: 100)
                .rotationEffect(.degrees(rotationAngle))
                .animation(isAnimating ? .linear(duration: 4).repeatForever(autoreverses: false) : .default, value: rotationAngle)
            
            // Middle ring
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.4)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 3
                )
                .frame(width: 75, height: 75)
                .rotationEffect(.degrees(-rotationAngle * 0.7))
            
            // Inner ring
            Circle()
                .stroke(Color.purple.opacity(0.4), lineWidth: 2)
                .frame(width: 50, height: 50)
                .rotationEffect(.degrees(rotationAngle * 1.3))
            
            // Processing nodes
            ForEach(0..<8, id: \.self) { node in
                Circle()
                    .fill(Color.cyan)
                    .frame(width: 6, height: 6)
                    .offset(
                        x: cos(Double(node) * .pi / 4) * 35,
                        y: sin(Double(node) * .pi / 4) * 35
                    )
                    .rotationEffect(.degrees(rotationAngle * 0.5))
                    .opacity(nodeOpacity)
                    .animation(isAnimating ? .easeInOut(duration: 1.5).repeatForever(autoreverses: true) : .default, value: nodeOpacity)
            }
            
            // Central brain
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white)
                    .frame(width: 40, height: 32)
                    .scaleEffect(pulseScale)
                    .animation(isAnimating ? .easeInOut(duration: 1.2).repeatForever(autoreverses: true) : .default, value: pulseScale)
                
                Image(systemName: "brain")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.cyan)
                    .scaleEffect(pulseScale)
            }
        }
        .onAppear {
            startProcessingAnimations()
        }
        .onDisappear {
            isAnimating = false
            pulseScale = 1.0
            glowOpacity = 0.0
            rotationAngle = 0.0
            nodeOpacity = 0.0
        }
    }
    
    private func startProcessingAnimations() {
        isAnimating = true
        rotationAngle = 360
        pulseScale = 1.15
        nodeOpacity = 1.0
    }
}

// MARK: - Animated Ellipsis
struct AnimatedEllipsis: View {
    @State private var animationPhase: Double = 0
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { index in
                Text(".")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.primary)
                    .opacity(dotOpacity(for: index))
                    .animation(
                        isAnimating ? .easeInOut(duration: 0.6)
                        .repeatForever(autoreverses: false)
                        .delay(Double(index) * 0.2) : .default,
                        value: animationPhase
                    )
            }
        }
        .onAppear {
            isAnimating = true
            animationPhase = 1
        }
        .onDisappear {
            isAnimating = false
            animationPhase = 0
        }
    }
    
    private func dotOpacity(for index: Int) -> Double {
        let phase = (animationPhase + Double(index) * 0.33).truncatingRemainder(dividingBy: 1.0)
        return 0.3 + 0.7 * Darwin.sin(phase * .pi * 2) * Darwin.sin(phase * .pi * 2)
    }
}

// MARK: - Enhanced Animated Clipboard Icon View
struct ClipboardIconView: View {
    let isForPasting: Bool
    @State private var showCompleted = false
    @State private var pulseScale: CGFloat = 1.0
    @State private var animationTask: DispatchWorkItem?
    @State private var sparkleOpacity: Double = 0.0
    @State private var sparkleScale: CGFloat = 0.5
    @State private var rotationAngle: Double = 0.0
    @State private var glowOpacity: Double = 0.0
    
    var body: some View {
        ZStack {
            // Sparkle effects around the clipboard
            if !showCompleted {
                ForEach(0..<6, id: \.self) { index in
                    Image(systemName: "sparkle")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(.blue.opacity(0.6))
                        .scaleEffect(sparkleScale)
                        .opacity(sparkleOpacity)
                        .offset(
                            x: cos(Double(index) * .pi / 3 + rotationAngle) * 20,
                            y: sin(Double(index) * .pi / 3 + rotationAngle) * 20
                        )
                }
            }
            
            if showCompleted {
                // Success checkmark with enhanced animation
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.green.opacity(0.3),
                                    Color.green.opacity(0.1),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 25
                            )
                        )
                        .frame(width: 50, height: 50)
                        .scaleEffect(pulseScale)
                    
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color.green.opacity(0.9),
                                    Color.mint.opacity(0.7)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .scaleEffect(pulseScale)
                        .shadow(color: Color.green.opacity(0.3), radius: 3, x: 0, y: 1)
                }
                .transition(.scale.combined(with: .opacity))
            } else {
                // Enhanced clipboard icon with animation
                ZStack {
                    // Glow effect
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.blue.opacity(0.4 * glowOpacity),
                                    Color.cyan.opacity(0.2 * glowOpacity),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 25
                            )
                        )
                        .frame(width: 50, height: 50)
                        .scaleEffect(pulseScale)
                    
                    // Background circle
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.blue.opacity(0.3),
                                    Color.cyan.opacity(0.2),
                                    Color.blue.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)
                        .shadow(color: Color.blue.opacity(0.2), radius: 8, x: 0, y: 4)
                        .scaleEffect(pulseScale)
                    
                    // Main clipboard icon
                    Image(systemName: isForPasting ? "clipboard.fill" : "doc.on.clipboard")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.white)
                        .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 1)
                        .scaleEffect(pulseScale)
                    
                    // Optional pasting indicator
                    if isForPasting {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.green)
                            .offset(x: 20, y: -15)
                            .background(
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 16, height: 16)
                            )
                            .scaleEffect(pulseScale)
                    }
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .onAppear(perform: startAnimation)
        .onDisappear(perform: cancelAnimation)
    }
    
    private func startAnimation() {
        // Initial pulse animation
        withAnimation(.easeInOut(duration: 0.3)) {
            pulseScale = 1.3
            glowOpacity = 1.0
        }
        
        // Sparkle animation
        withAnimation(.easeInOut(duration: 0.4).delay(0.1)) {
            sparkleOpacity = 1.0
            sparkleScale = 1.0
        }
        
        // Rotation animation for sparkles
        withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
            rotationAngle = 2 * .pi
        }
        
        // Transition to completed state
        let task = DispatchWorkItem {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0)) {
                self.showCompleted = true
                self.pulseScale = 1.0
                self.sparkleOpacity = 0.0
                self.glowOpacity = 0.0
            }
            
            // Final success pulse
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.pulseScale = 1.2
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        self.pulseScale = 1.0
                    }
                }
            }
        }
        self.animationTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: task)
    }
    
    private func cancelAnimation() {
        animationTask?.cancel()
    }
} 