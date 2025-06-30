import Foundation
import AVFoundation

enum AudioServiceError: Error {
    case audioEngineNotAvailable
    case inputNodeNotAvailable
    case fileCreationFailed
}

@MainActor
class AudioService {
    static let shared = AudioService()
    
    private var audioEngine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    
    private var audioFileURL: URL?
    
    func startRecording() throws {
        // 1. Setup Audio Engine
        audioEngine = AVAudioEngine()
        guard let engine = audioEngine else {
            throw AudioServiceError.audioEngineNotAvailable
        }
        
        // 2. Get the input node for the microphone
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        
        // 3. Setup a file to save the audio to
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.audioFileURL = documentsPath.appendingPathComponent("recording.caf")
        
        guard let fileURL = self.audioFileURL else {
            throw AudioServiceError.fileCreationFailed
        }
        
        // Delete previous recording if it exists
        try? FileManager.default.removeItem(at: fileURL)
        
        audioFile = try AVAudioFile(forWriting: fileURL, settings: inputFormat.settings)
        
        // 4. Install a "tap" on the input node to receive audio buffers
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] (buffer, when) in
            do {
                try self?.audioFile?.write(from: buffer)
            } catch {
                print("Error writing audio buffer to file: \(error)")
            }
        }
        
        // 5. Prepare and start the engine
        engine.prepare()
        try engine.start()
        
        print("🎙️ Recording started...")
    }
    
    func stopRecording() -> URL? {
        guard let engine = audioEngine else {
            print("Audio engine not running.")
            return nil
        }
        
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        
        // Close the file
        audioFile = nil
        
        print("👍 Recording stopped.")
        
        // Reset the audio engine instance
        self.audioEngine = nil
        
        return self.audioFileURL
    }
} 