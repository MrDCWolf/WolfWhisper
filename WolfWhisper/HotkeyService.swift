import Foundation
import CoreGraphics
import Carbon
import AppKit // For NSEvent

@MainActor
class HotkeyService {
    private var eventTap: CFMachPort?
    private var appState: AppStateModel

    // Define the hotkey combination (Command + Shift + D)
    private let hotkeyCode: CGKeyCode = CGKeyCode(kVK_ANSI_D)
    private let hotkeyFlags: CGEventFlags = [.maskCommand, .maskShift]

    init(appState: AppStateModel) {
        self.appState = appState
    }

    func startMonitoring() {
        // Ensure accessibility permissions are granted
        let options: NSDictionary = ["AXTrustedCheckOptionPrompt": true]
        guard AXIsProcessTrustedWithOptions(options) else {
            print("🛑 Accessibility permissions are not granted. Please grant them in System Settings.")
            appState.updateState(to: .error, message: "No accessibility permissions.")
            return
        }

        let eventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
        
        // Using a C-style callback function from within Swift
        let eventCallback: CGEventTapCallBack = { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
            guard let refcon = refcon else { return Unmanaged.passRetained(event) }
            
            // Re-bind the 'self' reference from the C context
            let mySelf = Unmanaged<HotkeyService>.fromOpaque(refcon).takeUnretainedValue()

            if let nsEvent = NSEvent(cgEvent: event) {
                // Convert CGEventFlags to NSEvent.ModifierFlags for comparison
                let requiredFlags = NSEvent.ModifierFlags(rawValue: UInt(mySelf.hotkeyFlags.rawValue))

                if nsEvent.keyCode == mySelf.hotkeyCode && nsEvent.modifierFlags.contains(requiredFlags) {
                    DispatchQueue.main.async {
                        if type == .keyDown {
                            mySelf.handleKeyDown()
                        } else if type == .keyUp {
                            mySelf.handleKeyUp()
                        }
                    }
                    // Absorb the event so it doesn't type the letter "D"
                    return nil
                }
            }
            return Unmanaged.passRetained(event)
        }

        // Pass 'self' as the refcon context to the C callback
        let selfAsUnsafeMutableRawPointer = Unmanaged.passUnretained(self).toOpaque()

        eventTap = CGEvent.tapCreate(tap: .cgSessionEventTap,
                                     place: .headInsertEventTap,
                                     options: .defaultTap,
                                     eventsOfInterest: CGEventMask(eventMask),
                                     callback: eventCallback,
                                     userInfo: selfAsUnsafeMutableRawPointer)

        if let eventTap = eventTap {
            let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
            CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            CGEvent.tapEnable(tap: eventTap, enable: true)
            print("🟢 Hotkey monitor started.")
        } else {
            print("🛑 Failed to create event tap.")
            appState.updateState(to: .error, message: "Failed to start hotkey monitor.")
        }
    }

    private func handleKeyDown() {
        guard appState.currentState == .idle else { return }
        do {
            try AudioService.shared.startRecording()
            appState.updateState(to: .recording)
        } catch {
            print("Error starting recording: \(error)")
            appState.updateState(to: .error, message: "Recording failed to start.")
        }
    }

    private func handleKeyUp() {
        guard appState.currentState == .recording else { return }
        if let audioURL = AudioService.shared.stopRecording() {
            appState.updateState(to: .processing)
            // TODO: Call NetworkService with the audioURL
            print("Audio ready for processing at: \(audioURL)")
            
            // For now, just go back to idle after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.appState.updateState(to: .idle)
            }
            
        } else {
            appState.updateState(to: .error, message: "Recording failed.")
        }
    }

    func stopMonitoring() {
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            self.eventTap = nil
            print("🔴 Hotkey monitor stopped.")
        }
    }
} 