import Foundation
import Carbon
import AppKit
import OSLog

@MainActor
final class HotkeyService {
    static let shared = HotkeyService()

    var onHotkeyPressed: (() -> Void)?

    private var hotkeyRef: EventHotKeyRef?
    private let logger = Logger(subsystem: "com.wolfwhisper.app", category: "HotkeyService")

    private init() {}

    func registerHotkey(modifiers: NSEvent.ModifierFlags, key: String) {
        unregisterHotkey() // Ensure any existing hotkey is cleared first
        
        guard let keyCode = KeyCodeMap.code(for: key) else {
            logger.error("Invalid key for hotkey: \(key)")
            return
        }

        let carbonModifiers = carbonModifiers(from: modifiers)
        
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = "htk1".fourCharCode
        hotKeyID.id = 1
        
        var eventType = EventTypeSpec()
        eventType.eventClass = OSType(kEventClassKeyboard)
        eventType.eventKind = OSType(kEventHotKeyPressed)
        
        let hotKeyHandler: @convention(c) (EventHandlerCallRef?, EventRef?, UnsafeMutableRawPointer?) -> OSStatus = { _, _, userData in
            guard let userData = userData else { return noErr }
            let service = Unmanaged<HotkeyService>.fromOpaque(userData).takeUnretainedValue()
            service.onHotkeyPressed?()
            return noErr
        }
        
        let status = RegisterEventHotKey(UInt32(keyCode), carbonModifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotkeyRef)
        
        if status == noErr {
            let userData = Unmanaged.passUnretained(self).toOpaque()
            InstallEventHandler(GetApplicationEventTarget(), hotKeyHandler, 1, &eventType, userData, nil)
            logger.info("Hotkey registered successfully.")
        } else {
            logger.error("Failed to register hotkey. Status: \(status)")
        }
    }
    
    func unregisterHotkey() {
        if let hotkeyRef = hotkeyRef {
            UnregisterEventHotKey(hotkeyRef)
            self.hotkeyRef = nil
            logger.info("Hotkey unregistered.")
        }
    }
    
    func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        logger.info("Text copied to clipboard.")
    }

    func pasteToActiveWindow() {
        logger.info("Attempting to paste text into the active window.")
        
        // Ensure accessibility permissions are granted before proceeding
        guard AXIsProcessTrusted() else {
            logger.warning("Accessibility permissions not granted. Cannot paste text.")
            // Optionally, you could trigger a state change here to show a UI message
            return
        }

        // Simulate Command+V
        let source = CGEventSource(stateID: .hidSystemState)
        
        let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: true)
        cmdDown?.flags = .maskCommand
        
        let vDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
        vDown?.flags = .maskCommand
        
        let vUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        vUp?.flags = .maskCommand
        
        let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: false)
        
        // Post events to the active process
        let loc = CGEventTapLocation.cghidEventTap
        cmdDown?.post(tap: loc)
        vDown?.post(tap: loc)
        vUp?.post(tap: loc)
        cmdUp?.post(tap: loc)
        
        logger.info("Paste command sent.")
    }
    
    private func carbonModifiers(from cocoaModifiers: NSEvent.ModifierFlags) -> UInt32 {
        var carbonFlags: UInt32 = 0
        if cocoaModifiers.contains(.command) { carbonFlags |= UInt32(cmdKey) }
        if cocoaModifiers.contains(.option) { carbonFlags |= UInt32(optionKey) }
        if cocoaModifiers.contains(.control) { carbonFlags |= UInt32(controlKey) }
        if cocoaModifiers.contains(.shift) { carbonFlags |= UInt32(shiftKey) }
        return carbonFlags
    }
} 