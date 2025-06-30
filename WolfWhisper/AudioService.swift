@preconcurrency import AVFoundation
import AppKit
import os

@MainActor
class AudioService: ObservableObject {
    private let appState: AppStateModel
    private let transcriptionService: TranscriptionService

    private var audioRecorder: AVAudioRecorder?
    private var audioFileURL: URL?
    private var isRecording = false

    init(appState: AppStateModel, transcriptionService: TranscriptionService) {
        self.appState = appState
        self.transcriptionService = transcriptionService
    }
    
    @MainActor
    func startRecording() {
        guard !isRecording else {
            print("⚠️ Already recording")
            return
        }
        
        Task {
            await self.setupAndStartRecording()
        }
    }

    @MainActor
    private func setupAndStartRecording() async {
        print("🎤 Starting recording setup...")
        
        // First check microphone permissions
        let microphoneStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        print("🔐 Microphone permission status: \(microphoneStatus.rawValue)")
        
        switch microphoneStatus {
        case .notDetermined:
            print("🔐 Requesting microphone permission...")
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            if !granted {
                appState.updateState(to: .idle, message: "Microphone access denied")
                return
            }
            print("✅ Microphone permission granted")
        case .denied, .restricted:
            appState.updateState(to: .idle, message: "Microphone access denied. Please enable in System Preferences.")
            return
        case .authorized:
            print("✅ Microphone permission already granted")
        @unknown default:
            appState.updateState(to: .idle, message: "Unknown microphone permission status")
            return
        }
        
        do {
            // Create temporary file
            let fileManager = FileManager.default
            let tempDir = fileManager.temporaryDirectory
            let filePath = tempDir.appendingPathComponent("wolfwhisper_\(Date().timeIntervalSince1970).m4a")
            print("📁 Recording to: \(filePath)")
            
            // Configure recording settings
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100.0,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            
            // Create and configure recorder
            audioRecorder = try AVAudioRecorder(url: filePath, settings: settings)
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.prepareToRecord()
            
            // Start recording
            let success = audioRecorder?.record() ?? false
            if success {
                isRecording = true
                audioFileURL = filePath
                appState.updateState(to: .recording)
                print("✅ Recording started successfully")
            } else {
                print("❌ Failed to start recording")
                appState.updateState(to: .idle, message: "Failed to start recording")
            }
            
        } catch {
            print("❌ Failed to setup recording: \(error)")
            appState.updateState(to: .idle, message: "Failed to setup recording: \(error.localizedDescription)")
        }
    }

    @MainActor
    func stopRecording() {
        print("🛑 Stop recording requested")
        guard isRecording else {
            print("⚠️ Not currently recording")
            return
        }
        
        finishRecording()
    }

    @MainActor
    private func finishRecording() {
        print("🏁 Finishing recording...")
        guard isRecording else {
            print("⚠️ finishRecording called but not recording")
            return
        }
        
        isRecording = false
        
        // Stop the recorder
        audioRecorder?.stop()
        audioRecorder = nil
        
        guard let audioFileURL = self.audioFileURL else {
            appState.updateState(to: .idle, message: "No audio file to transcribe")
            return
        }

        Task {
            await transcribeAudio(at: audioFileURL)
        }
    }

    @MainActor
    func cancelRecording() {
        print("❌ Cancelling recording")
        isRecording = false
        
        // Stop the recorder
        audioRecorder?.stop()
        audioRecorder = nil
        
        if let url = audioFileURL {
            try? FileManager.default.removeItem(at: url)
        }
        audioFileURL = nil
        appState.updateState(to: .idle)
        print("🗑️ Recording cancelled and file deleted.")
    }

    @MainActor
    private func transcribeAudio(at url: URL) async {
        print("📝 Starting transcription...")
        appState.updateState(to: .transcribing)
        do {
            let transcribedText = try await transcriptionService.transcribe(audioURL: url)
            print("✅ Transcription successful: \(transcribedText)")

            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(transcribedText, forType: .string)
            appState.updateState(to: .idle, message: "Copied to clipboard!")

            // Clean up temp file
            try? FileManager.default.removeItem(at: url)
            audioFileURL = nil

        } catch {
            print("🛑 Transcription failed: \(error)")
            appState.updateState(to: .idle, message: "Transcription failed: \(error.localizedDescription)")
            
            // Clean up temp file on error
            try? FileManager.default.removeItem(at: url)
            audioFileURL = nil
        }
    }
} 