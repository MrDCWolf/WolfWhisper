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
        print("🔧 HotkeyService.registerHotkey called with modifiers: \(modifiers), key: \(key)")
        
        // Unregister existing hotkey first
        unregisterHotkey()
        
        let keyCode = Int(key)
        let carbonModifiers = carbonModifiersFromFlags(modifiers)
        
        print("🔧 Converted to keyCode: \(keyCode), carbonModifiers: \(carbonModifiers)")
        
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
            print("✅ Hotkey registered successfully with modifiers: \(modifiers), key: \(key)")
        } else {
            print("❌ Failed to register hotkey: \(status) (modifiers: \(modifiers), key: \(key))")
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
        let eventTypes = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))
        ]
        
        let callback: EventHandlerProcPtr = { (nextHandler, theEvent, userData) -> OSStatus in
            print("🔥 Hotkey event received!")
            
            // Get the HotkeyService instance from userData
            let hotkeyService = Unmanaged<HotkeyService>.fromOpaque(userData!).takeUnretainedValue()
            
            // Trigger the callback on the main thread
            DispatchQueue.main.async {
                print("🔥 Calling hotkey callback...")
                hotkeyService.onHotkeyPressed?()
            }
            
            return noErr
        }
        
        let userData = Unmanaged.passUnretained(self).toOpaque()
        
        InstallEventHandler(
            GetEventDispatcherTarget(),
            callback,
            1,
            eventTypes,
            userData,
            &eventHandler
        )
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
        print("🔧 Converting modifier flags: \(flags)")
        var carbonModifiers = 0
        
        // The flags come from our hotkey recorder which stores Carbon modifier flags
        if flags & UInt(cmdKey) != 0 {
            carbonModifiers |= cmdKey
            print("🔧 Added cmdKey")
        }
        if flags & UInt(optionKey) != 0 {
            carbonModifiers |= optionKey
            print("🔧 Added optionKey")
        }
        if flags & UInt(controlKey) != 0 {
            carbonModifiers |= controlKey
            print("🔧 Added controlKey")
        }
        if flags & UInt(shiftKey) != 0 {
            carbonModifiers |= shiftKey
            print("🔧 Added shiftKey")
        }
        
        print("🔧 Final carbonModifiers: \(carbonModifiers)")
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
        print("Attempting to paste to active window...")
        
        // Check if we have accessibility permissions
        if !hasAccessibilityPermissions() {
            print("No accessibility permissions - requesting...")
            requestAccessibilityPermissions()
            return
        }
        
        // First try to use accessibility API to find the focused element
        // This ensures we're actually using accessibility features
        let systemWideElement = AXUIElementCreateSystemWide()
        var focusedApp: AnyObject?
        let result = AXUIElementCopyAttributeValue(systemWideElement, kAXFocusedApplicationAttribute as CFString, &focusedApp)
        
        if result == .success {
            print("✅ Successfully accessed focused application via accessibility API")
        } else {
            print("⚠️ Failed to access focused application: \(result)")
        }
        
        // Simulate Cmd+V to paste
        let source = CGEventSource(stateID: .hidSystemState)
        
        // Key down for Cmd+V
        let cmdVDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true) // V key
        cmdVDown?.flags = .maskCommand
        
        // Key up for Cmd+V
        let cmdVUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false) // V key
        cmdVUp?.flags = .maskCommand
        
        // Post the events
        cmdVDown?.post(tap: .cghidEventTap)
        cmdVUp?.post(tap: .cghidEventTap)
        
        print("Paste events sent")
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
        print("🔐 Requesting accessibility permissions...")
        
        // First check if we already have permissions
        if AXIsProcessTrusted() {
            print("🔐 Already have accessibility permissions")
            return
        }
        
        // Try to actually use accessibility features to trigger the proper permission request
        // This will cause macOS to show the permission dialog
        let systemWideElement = AXUIElementCreateSystemWide()
        var focusedApp: AnyObject?
        let result = AXUIElementCopyAttributeValue(systemWideElement, kAXFocusedApplicationAttribute as CFString, &focusedApp)
        
        print("🔐 Accessibility API call result: \(result)")
        
        // Always try with the prompt option to ensure the dialog is shown
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        print("🔐 Accessibility permission request result: \(trusted)")
        
        // If still no permissions after a delay, open System Settings as fallback
        if !trusted {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                if !AXIsProcessTrusted() {
                    print("🔐 Still no permissions after delay, opening System Settings...")
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }
    }
} 