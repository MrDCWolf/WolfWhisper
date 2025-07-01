@preconcurrency import AVFoundation
import Foundation
import CoreAudio

@MainActor
class AudioService: NSObject, ObservableObject {
    static let shared = AudioService()
    
    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?
    private var levelTimer: Timer?
    
    // Callbacks
    var onStateChange: ((AppState) -> Void)?
    var onAudioLevelsUpdate: (([Float]) -> Void)?
    
    private override init() {
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
        
        guard let url = recordingURL else {
            throw AudioError.fileCreationFailed
        }
        
        // Set up recording settings
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            // Create and configure the audio recorder
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            
            // Start recording
            let success = audioRecorder?.record()
            if success == true {
                onStateChange?(.recording)
                startLevelMonitoring()
            } else {
                throw AudioError.recordingFailed
            }
        } catch {
            throw AudioError.recordingFailed
        }
    }
    
    func stopRecording() async throws -> Data {
        guard let recorder = audioRecorder,
              let url = recordingURL else {
            throw AudioError.noActiveRecording
        }
        
        // Stop recording
        recorder.stop()
        stopLevelMonitoring()
        
        // Read the recorded data
        do {
            let data = try Data(contentsOf: url)
            
            // Clean up
            try? FileManager.default.removeItem(at: url)
            audioRecorder = nil
            recordingURL = nil
            
            return data
        } catch {
            throw AudioError.fileReadFailed
        }
    }
    
    private func startLevelMonitoring() {
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateAudioLevels()
            }
        }
    }
    
    private func stopLevelMonitoring() {
        levelTimer?.invalidate()
        levelTimer = nil
        
        // Send empty levels to reset the UI
        onAudioLevelsUpdate?([])
    }
    
    private func updateAudioLevels() {
        guard let recorder = audioRecorder else { return }
        
        recorder.updateMeters()
        
        // Get the average power level
        let averagePower = recorder.averagePower(forChannel: 0)
        let peakPower = recorder.peakPower(forChannel: 0)
        
        // Convert dB to a normalized value (0.0 to 1.0)
        let normalizedAverage = normalizeAudioLevel(averagePower)
        let normalizedPeak = normalizeAudioLevel(peakPower)
        
        // Create an array of levels for the waveform visualization
        // We'll simulate multiple bars by adding some variation
        var levels: [Float] = []
        let baseLevel = normalizedAverage
        
        for _ in 0..<16 {
            let variation = Float.random(in: -0.1...0.1)
            let level = max(0.0, min(1.0, baseLevel + variation))
            levels.append(level)
        }
        
        // Add some emphasis to the center bars
        if levels.count >= 8 {
            levels[6] = max(levels[6], normalizedPeak * 0.8)
            levels[7] = max(levels[7], normalizedPeak * 0.9)
            levels[8] = max(levels[8], normalizedPeak)
            levels[9] = max(levels[9], normalizedPeak * 0.9)
        }
        
        onAudioLevelsUpdate?(levels)
    }
    
    private func normalizeAudioLevel(_ decibels: Float) -> Float {
        // Convert dB to linear scale
        // -60 dB is considered silence, 0 dB is maximum
        let minDB: Float = -60.0
        let maxDB: Float = 0.0
        
        let clampedDB = max(minDB, min(maxDB, decibels))
        let normalized = (clampedDB - minDB) / (maxDB - minDB)
        
        return normalized
    }
}

// MARK: - AVAudioRecorderDelegate
extension AudioService: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            if !flag {
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