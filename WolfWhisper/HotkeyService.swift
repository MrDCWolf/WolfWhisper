import Foundation
@preconcurrency import Carbon
import Cocoa

@MainActor
class HotkeyService: ObservableObject {
    static let shared = HotkeyService()
    
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var isRegistered = false
    
    // Callback for when hotkey is pressed
    var onHotkeyPressed: (() -> Void)?
    
    private init() {}
    
    func registerHotkey(modifiers: UInt, key: UInt16) {
        NSLog("🔧 HotkeyService.registerHotkey called with modifiers: \(modifiers), key: \(key)")
        
        // Unregister existing hotkey first
        unregisterHotkey()
        
        let keyCode = Int(key)
        let carbonModifiers = carbonModifiersFromFlags(modifiers)
        
        NSLog("🔧 Converted to keyCode: \(keyCode), carbonModifiers: \(carbonModifiers)")
        
        // Register the hotkey
        let hotKeyID = EventHotKeyID(signature: fourCharCodeFrom("WLFW"), id: 1)
        
        let status = RegisterEventHotKey(
            UInt32(keyCode),
            UInt32(carbonModifiers),
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )
        
        if status == noErr {
            isRegistered = true
            setupEventHandler()
            NSLog("✅ Hotkey registered successfully with modifiers: \(modifiers), key: \(key)")
        } else {
            NSLog("❌ Failed to register hotkey: \(status) (modifiers: \(modifiers), key: \(key))")
        }
    }
    
    func unregisterHotkey() {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        
        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
        
        isRegistered = false
    }
    
    nonisolated private func cleanupResources() {
        // Cleanup without accessing actor-isolated properties
        // This is called from deinit which is nonisolated
    }
    
    private func setupEventHandler() {
        NSLog("🔧 Setting up event handler...")
        
        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))
        
        let callback: EventHandlerProcPtr = { (nextHandler, theEvent, userData) -> OSStatus in
            NSLog("🔥 HOTKEY EVENT TRIGGERED!")
            
            // Get the hotkey ID
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(theEvent, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            
            if status == noErr {
                NSLog("🔥 Hotkey ID: \(hotKeyID.id)")
                
                // Call the callback on the main thread ASYNCHRONOUSLY
                NSLog("🔥 Calling onHotkeyPressed callback")
                DispatchQueue.main.async {
                    NSLog("🔥 Executing onHotkeyPressed callback on main thread")
                    if let instance = Unmanaged<HotkeyService>.fromOpaque(userData!).takeUnretainedValue().onHotkeyPressed {
                        instance()
                    }
                }
            }
            
            return noErr
        }
        
        let status = InstallEventHandler(GetEventDispatcherTarget(), callback, 1, &eventSpec, Unmanaged.passUnretained(self).toOpaque(), &eventHandler)
        
        if status == noErr {
            NSLog("✅ Event handler installed successfully")
        } else {
            NSLog("❌ Failed to install event handler: \(status)")
        }
    }
    
    // Convert string representation to Carbon key codes
    private func keyCodeForString(_ key: String) -> Int? {
        let keyMap: [String: Int] = [
            "A": kVK_ANSI_A, "B": kVK_ANSI_B, "C": kVK_ANSI_C, "D": kVK_ANSI_D,
            "E": kVK_ANSI_E, "F": kVK_ANSI_F, "G": kVK_ANSI_G, "H": kVK_ANSI_H,
            "I": kVK_ANSI_I, "J": kVK_ANSI_J, "K": kVK_ANSI_K, "L": kVK_ANSI_L,
            "M": kVK_ANSI_M, "N": kVK_ANSI_N, "O": kVK_ANSI_O, "P": kVK_ANSI_P,
            "Q": kVK_ANSI_Q, "R": kVK_ANSI_R, "S": kVK_ANSI_S, "T": kVK_ANSI_T,
            "U": kVK_ANSI_U, "V": kVK_ANSI_V, "W": kVK_ANSI_W, "X": kVK_ANSI_X,
            "Y": kVK_ANSI_Y, "Z": kVK_ANSI_Z,
            "0": kVK_ANSI_0, "1": kVK_ANSI_1, "2": kVK_ANSI_2, "3": kVK_ANSI_3,
            "4": kVK_ANSI_4, "5": kVK_ANSI_5, "6": kVK_ANSI_6, "7": kVK_ANSI_7,
            "8": kVK_ANSI_8, "9": kVK_ANSI_9,
            "Space": kVK_Space, "Return": kVK_Return, "Tab": kVK_Tab,
            "Escape": kVK_Escape, "Delete": kVK_Delete, "ForwardDelete": kVK_ForwardDelete,
            "F1": kVK_F1, "F2": kVK_F2, "F3": kVK_F3, "F4": kVK_F4,
            "F5": kVK_F5, "F6": kVK_F6, "F7": kVK_F7, "F8": kVK_F8,
            "F9": kVK_F9, "F10": kVK_F10, "F11": kVK_F11, "F12": kVK_F12
        ]
        
        return keyMap[key.uppercased()]
    }
    
    // Convert UInt modifier flags to Carbon modifiers
    private func carbonModifiersFromFlags(_ flags: UInt) -> Int {
        NSLog("🔧 Converting modifier flags: \(flags)")
        var carbonModifiers = 0
        
        // The flags come from our hotkey recorder which stores Carbon modifier flags
        if flags & UInt(cmdKey) != 0 {
            carbonModifiers |= cmdKey
            NSLog("🔧 Added cmdKey")
        }
        if flags & UInt(optionKey) != 0 {
            carbonModifiers |= optionKey
            NSLog("🔧 Added optionKey")
        }
        if flags & UInt(controlKey) != 0 {
            carbonModifiers |= controlKey
            NSLog("🔧 Added controlKey")
        }
        if flags & UInt(shiftKey) != 0 {
            carbonModifiers |= shiftKey
            NSLog("🔧 Added shiftKey")
        }
        
        NSLog("🔧 Final carbonModifiers: \(carbonModifiers)")
        return carbonModifiers
    }
    
    // Helper function to create OSType from string
    private func fourCharCodeFrom(_ string: String) -> FourCharCode {
        let utf8 = string.utf8
        let bytes = Array(utf8.prefix(4))
        return bytes.withUnsafeBufferPointer {
            $0.baseAddress!.withMemoryRebound(to: FourCharCode.self, capacity: 1) {
                $0.pointee
            }
        }
    }
    
    deinit {
        // Clean up hotkey registration - simplified for concurrency safety
        cleanupResources()
    }
}

// Extension to handle clipboard operations and text insertion
extension HotkeyService {
    func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
    
    func pasteToActiveWindow() {
        NSLog("🔥 pasteToActiveWindow called")
        
        // Check if we have accessibility permission
        let hasAccessibility = AXIsProcessTrusted()
        NSLog("🔥 Accessibility permission: \(hasAccessibility)")
        
        if !hasAccessibility {
            NSLog("🔥 No accessibility permission - cannot paste")
            
            // Request accessibility permission
            let alert = NSAlert()
            alert.messageText = "Accessibility Permission Required"
            alert.informativeText = "WolfWhisper needs accessibility permission to paste text to other applications. Please grant permission in System Preferences."
            alert.addButton(withTitle: "Open System Preferences")
            alert.addButton(withTitle: "Cancel")
            
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                NSWorkspace.shared.open(url)
            }
            return
        }
        
        NSLog("🔥 Have accessibility permission - proceeding with paste")
        
        // Simulate Cmd+V key press
        let source = CGEventSource(stateID: .hidSystemState)
        
        // Create key down event for Cmd+V
        let keyDownEvent = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true) // V key
        keyDownEvent?.flags = .maskCommand
        
        // Create key up event for Cmd+V
        let keyUpEvent = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false) // V key
        keyUpEvent?.flags = .maskCommand
        
        // Post the events
        keyDownEvent?.post(tap: .cghidEventTap)
        keyUpEvent?.post(tap: .cghidEventTap)
        
        NSLog("🔥 Cmd+V key events posted")
    }
    
    func copyAndPaste(_ text: String) {
        copyToClipboard(text)
        
        // Small delay to ensure clipboard is updated
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.pasteToActiveWindow()
        }
    }
    
    // Check if we have accessibility permissions for text insertion
    func hasAccessibilityPermissions() -> Bool {
        return AXIsProcessTrusted()
    }
    
    func requestAccessibilityPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }
} 