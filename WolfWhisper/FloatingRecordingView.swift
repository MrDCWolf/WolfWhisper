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
    
    var body: some View {
        ZStack {
            // Background with translucent vibrancy material
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 8)
            
            VStack(spacing: 20) {
                // Main visualizer and content
                switch appState.currentState {
                case .recording:
                    RecordingStateView(audioLevels: appState.audioLevels, appState: appState)
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    
                case .transcribing:
                    TranscribingStateView(appState: appState)
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    
                case .idle:
                    CompletedStateView()
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }
            .padding(32)
        }
        .frame(width: 280, height: 280)
        .animation(.easeInOut(duration: 0.3), value: appState.currentState)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.2)) {
                // Appearance animation is handled by the window presentation
            }
        }
    }
}

// MARK: - Recording State View with Data Wave Visualizer
struct RecordingStateView: View {
    let audioLevels: [Float]
    @ObservedObject var appState: AppStateModel
    
    var body: some View {
        VStack(spacing: 24) {
            // Data Wave Visualizer
            DataWaveVisualizer(audioLevels: audioLevels)
            
            VStack(spacing: 8) {
                // Status text with animated ellipsis
                HStack(spacing: 0) {
                    Text("Recording")
                        .font(.title3.weight(.medium))
                        .foregroundStyle(.primary)
                    
                    AnimatedEllipsis()
                }
                

                
                // Instructional text
                Text("Press hotkey again to stop")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
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
        let audioIndex = Int(Float(index) / Float(barCount) * Float(audioLevels.count))
        if audioIndex < audioLevels.count {
            return audioLevels[audioIndex]
        }
        return 0.0
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
                .animation(.easeInOut(duration: 0.1), value: Double(audioLevel))
            
            Spacer()
        }
        .frame(height: maxHeight)
    }
}

// MARK: - Transcribing State View
struct TranscribingStateView: View {
    @ObservedObject var appState: AppStateModel
    
    var body: some View {
        VStack(spacing: 24) {
            // Transform wave into processing indicator
            ProcessingIndicator()
            
            VStack(spacing: 8) {
                // Show step-by-step progress
                VStack(spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.green)
                        Text("Transcribe")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.primary)
                        Spacer()
                    }
                    

                }
                
                Text("Please wait...")
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
    @State private var rotationAngle: Double = 0
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(Color.white.opacity(0.2), lineWidth: 3)
                .frame(width: 120, height: 120)
            
            // Animated arc
            Circle()
                .trim(from: 0, to: 0.3)
                .stroke(
                    Color.white.opacity(0.8),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .frame(width: 120, height: 120)
                .rotationEffect(.degrees(rotationAngle))
        }
        .onAppear {
            withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                rotationAngle = 360
            }
        }
    }
}

// MARK: - Animated Ellipsis
struct AnimatedEllipsis: View {
    @State private var animationPhase: Double = 0
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { index in
                Text(".")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.primary)
                    .opacity(dotOpacity(for: index))
                    .animation(
                        .easeInOut(duration: 0.6)
                        .repeatForever(autoreverses: false)
                        .delay(Double(index) * 0.2),
                        value: animationPhase
                    )
            }
        }
        .onAppear {
            animationPhase = 1
        }
    }
    
    private func dotOpacity(for index: Int) -> Double {
        let phase = (animationPhase + Double(index) * 0.33).truncatingRemainder(dividingBy: 1.0)
        return 0.3 + 0.7 * Darwin.sin(phase * .pi * 2) * Darwin.sin(phase * .pi * 2)
    }
} 