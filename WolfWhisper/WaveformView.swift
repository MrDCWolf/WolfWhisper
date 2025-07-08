import SwiftUI

struct WaveformView: View {
    let audioLevels: [Float]
    let isRecording: Bool
    let barCount: Int
    
    @State private var animationPhase: Double = 0
    
    init(audioLevels: [Float] = [], isRecording: Bool = false, barCount: Int = 32) {
        self.audioLevels = audioLevels
        self.isRecording = isRecording
        self.barCount = barCount
    }
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<barCount, id: \.self) { index in
                WaveformBar(
                    height: barHeight(for: index),
                    isRecording: isRecording,
                    animationDelay: Double(index) * 0.05
                )
            }
        }
        .onAppear {
            if isRecording {
                startAnimation()
            }
        }
        .onChange(of: isRecording) { recording in
            if recording {
                startAnimation()
            }
        }
    }
    
    private func barHeight(for index: Int) -> CGFloat {
        if audioLevels.isEmpty {
            // Generate a subtle idle animation
            let baseHeight: CGFloat = 4
            let variation = sin(animationPhase + Double(index) * 0.5) * 2
            return max(2, baseHeight + variation)
        } else {
            // Use actual audio levels
            let levelIndex = min(index, audioLevels.count - 1)
            let level = audioLevels[levelIndex]
            return max(2, CGFloat(level) * 40) // Scale to reasonable height
        }
    }
    
    private func startAnimation() {
        withAnimation(.linear(duration: 0.1).repeatForever(autoreverses: false)) {
            animationPhase += .pi * 2
        }
    }
}

struct WaveformBar: View {
    let height: CGFloat
    let isRecording: Bool
    let animationDelay: Double
    
    @State private var animatedHeight: CGFloat = 2
    @State private var opacity: Double = 0.3
    
    var body: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.blue.opacity(0.8),
                        Color.blue.opacity(0.4)
                    ]),
                    startPoint: .bottom,
                    endPoint: .top
                )
            )
            .frame(width: 3, height: animatedHeight)
            .opacity(opacity)
            .animation(
                .easeInOut(duration: 0.3)
                .delay(animationDelay),
                value: animatedHeight
            )
            .onAppear {
                updateHeight()
            }
            .onChange(of: height) { _ in
                updateHeight()
            }
            .onChange(of: isRecording) { recording in
                opacity = recording ? 1.0 : 0.3
            }
    }
    
    private func updateHeight() {
        animatedHeight = height
    }
}

struct RecordingButton: View {
    let state: AppState
    let isRecording: Bool
    let audioLevels: [Float]
    let action: () -> Void
    
    @State private var isPressed = false
    @State private var pulseScale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            // Main button circle with enhanced shadow for depth
            Circle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: gradientColors),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 80, height: 80)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .shadow(
                    color: Color.black.opacity(0.15),
                    radius: 12,
                    x: 0,
                    y: 6
                )
                .scaleEffect(pulseScale)
            
            // Content based on state
            Group {
                switch state {
                case .idle:
                    IdleButtonContent()
                case .recording:
                    RecordingButtonContent(audioLevels: audioLevels)
                case .transcribing:
                    TranscribingButtonContent()
                }
            }
        }
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .onTapGesture {
            action()
        }
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, perform: {}, onPressingChanged: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        })
        .onAppear {
            startPulseAnimation()
        }
        .onChange(of: isRecording) { recording in
            if recording {
                startPulseAnimation()
            }
        }
    }
    
    private var gradientColors: [Color] {
        switch state {
        case .idle:
            return [Color.blue, Color.blue.opacity(0.8)]
        case .recording:
            return [Color.red, Color.red.opacity(0.8)]
        case .transcribing:
            return [Color.orange, Color.orange.opacity(0.8)]
        }
    }
    
    private func startPulseAnimation() {
        guard isRecording else { return }
        
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            pulseScale = 1.1
        }
    }
}

struct IdleButtonContent: View {
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "mic.fill")
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(.white)
            
            Text("Tap to Record")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white.opacity(0.9))
        }
    }
}

struct RecordingButtonContent: View {
    let audioLevels: [Float]
    
    var body: some View {
        VStack(spacing: 8) {
            // Waveform visualization
            WaveformView(
                audioLevels: audioLevels,
                isRecording: true,
                barCount: 12
            )
            .frame(height: 30)
            
            Text("Recording...")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white.opacity(0.9))
        }
    }
}

struct TranscribingButtonContent: View {
    @State private var rotationAngle: Double = 0
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "text.quote")
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(.white)
                .rotationEffect(.degrees(rotationAngle))
                .onAppear {
                    withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                        rotationAngle = 360
                    }
                }
            
            Text("Transcribing...")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white.opacity(0.9))
        }
    }
}

// Compact waveform for menu bar or small spaces
struct CompactWaveformView: View {
    let audioLevels: [Float]
    let isRecording: Bool
    
    var body: some View {
        HStack(spacing: 1) {
            ForEach(0..<8, id: \.self) { index in
                RoundedRectangle(cornerRadius: 0.5)
                    .fill(Color.blue)
                    .frame(width: 2, height: barHeight(for: index))
                    .animation(.easeInOut(duration: 0.1), value: barHeight(for: index))
            }
        }
        .frame(height: 16)
    }
    
    private func barHeight(for index: Int) -> CGFloat {
        if audioLevels.isEmpty {
            return isRecording ? CGFloat.random(in: 2...12) : 2
        } else {
            let levelIndex = min(index, audioLevels.count - 1)
            let level = audioLevels[levelIndex]
            return max(2, CGFloat(level) * 16)
        }
    }
}

// Preview helpers
struct WaveformView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 40) {
            // Idle state
            RecordingButton(
                state: .idle,
                isRecording: false,
                audioLevels: [],
                action: {}
            )
            
            // Recording state
            RecordingButton(
                state: .recording,
                isRecording: true,
                audioLevels: [0.3, 0.7, 0.5, 0.9, 0.4, 0.8, 0.6, 0.2],
                action: {}
            )
            
            // Transcribing state
            RecordingButton(
                state: .transcribing,
                isRecording: false,
                audioLevels: [],
                action: {}
            )
            
            // Compact waveform
            CompactWaveformView(
                audioLevels: [0.3, 0.7, 0.5, 0.9, 0.4, 0.8, 0.6, 0.2],
                isRecording: true
            )
        }
        .padding()
        .background(Color.gray.opacity(0.1))
    }
} 