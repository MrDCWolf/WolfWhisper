@preconcurrency import AVFoundation
import Foundation
import CoreAudio

@MainActor
class AudioService: NSObject, ObservableObject, AVAudioRecorderDelegate {
    static let shared = AudioService()

    enum State {
        case idle
        case recording
        case transcribing
    }
    
    @Published var state: State = .idle
    @Published var audioLevels: Float = 0.0
    
    // Callbacks
    var onStateChange: ((AppStateValue) -> Void)?
    var onAudioLevelsUpdate: ((Float) -> Void)?
    
    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL
    private var levelTimer: Timer?
    
    private override init() { // Make init private for singleton
        let tempDir = FileManager.default.temporaryDirectory
        self.recordingURL = tempDir.appendingPathComponent("recording.m4a")
        super.init()
    }

    func getCurrentMicrophoneName() -> String {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var deviceID: AudioDeviceID = 0
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &deviceID
        )
        
        guard status == noErr else {
            return "System Default"
        }
        
        // Get device name
        address.mSelector = kAudioDevicePropertyDeviceNameCFString
        address.mScope = kAudioObjectPropertyScopeGlobal
        
        var deviceName: Unmanaged<CFString>?
        size = UInt32(MemoryLayout<Unmanaged<CFString>>.size)
        
        let nameStatus = AudioObjectGetPropertyData(
            deviceID,
            &address,
            0,
            nil,
            &size,
            &deviceName
        )
        
        if nameStatus == noErr, let name = deviceName?.takeUnretainedValue() {
            return name as String
        }
        
        return "System Default"
    }
    
    func startRecording() async throws {
        // Request microphone permission
        let granted = await AVCaptureDevice.requestAccess(for: .audio)
        guard granted else {
            throw AudioError.permissionDenied
        }
        
        // Create a unique file URL for this recording
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "recording_\(Date().timeIntervalSince1970).m4a"
        recordingURL = tempDir.appendingPathComponent(fileName)
        
        // Set up recording settings
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            // Create and configure the audio recorder
            audioRecorder = try AVAudioRecorder(url: recordingURL, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()
            
            // Start timer to update audio levels
            levelTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    self?.updateAudioLevels()
                }
            }
            
            onStateChange?(.recording)
        } catch {
            stopRecordingInternal()
            throw error
        }
    }
    
    func stopRecording() async throws -> Data {
        stopRecordingInternal()
        
        // Read the audio file data
        do {
            let audioData = try Data(contentsOf: recordingURL)
            // Clean up the recording file
            try? FileManager.default.removeItem(at: recordingURL)
            onStateChange?(.idle)
            return audioData
        } catch {
            throw error
        }
    }
    
    private func stopRecordingInternal() {
        audioRecorder?.stop()
        levelTimer?.invalidate()
        levelTimer = nil
        
        // Send empty levels to reset the UI
        onAudioLevelsUpdate?(0.0)
    }
    
    @objc private func updateAudioLevels() {
        guard let recorder = audioRecorder else { return }
        recorder.updateMeters()
        
        // Calculate average power
        let averagePower = recorder.averagePower(forChannel: 0)
        
        // Normalize to 0-1 range
        let normalizedLevel = 1.0 - (abs(averagePower) / 160.0)
        
        onAudioLevelsUpdate?(normalizedLevel)
    }
    
    // MARK: - AVAudioRecorderDelegate
    
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            // Handle recording error
            Task { @MainActor in
                onStateChange?(.idle)
            }
        }
    }
    
    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task { @MainActor in
            onStateChange?(.idle)
        }
    }
}

// MARK: - Error Types
enum AudioError: LocalizedError {
    case permissionDenied
    case fileCreationFailed
    case recordingFailed
    case noActiveRecording
    case fileReadFailed
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Microphone permission denied"
        case .fileCreationFailed:
            return "Could not create recording file"
        case .recordingFailed:
            return "Recording failed to start"
        case .noActiveRecording:
            return "No active recording to stop"
        case .fileReadFailed:
            return "Could not read recording file"
        }
    }
} 