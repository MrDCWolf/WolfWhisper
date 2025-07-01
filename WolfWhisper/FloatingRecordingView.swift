import SwiftUI

struct FloatingRecordingView: View {
    @ObservedObject var appState: AppStateModel
    
    var body: some View {
        ZStack {
            // Background with blur effect
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(radius: 10)
            
            VStack(spacing: 12) {
                // App icon and title
                HStack(spacing: 8) {
                    Image(systemName: "waveform")
                        .font(.title2)
                        .foregroundColor(.blue)
                    
                    Text("WolfWhisper")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                
                // Recording state indicator
                switch appState.currentState {
                case .recording:
                    VStack(spacing: 8) {
                        // Animated recording indicator
                        HStack(spacing: 4) {
                            ForEach(0..<5, id: \.self) { index in
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.red)
                                    .frame(width: 4, height: CGFloat.random(in: 10...30))
                                    .animation(
                                        .easeInOut(duration: 0.5)
                                        .repeatForever(autoreverses: true)
                                        .delay(Double(index) * 0.1),
                                        value: appState.audioLevels
                                    )
                            }
                        }
                        .frame(height: 40)
                        
                        Text("Recording...")
                            .font(.subheadline)
                            .foregroundColor(.red)
                        
                        Text("Press hotkey again to stop")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                case .transcribing:
                    VStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.8)
                        
                        Text("Transcribing...")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                        
                        Text("Please wait...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                case .idle:
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.green)
                        
                        Text("Complete!")
                            .font(.subheadline)
                            .foregroundColor(.green)
                    }
                }
            }
            .padding(20)
        }
        .frame(width: 280, height: 180)
    }
} 