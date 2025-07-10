import Foundation
@preconcurrency import Carbon
import Cocoa

@MainActor
class HotkeyService: ObservableObject {
    static let shared = HotkeyService()
    
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var isRegistered = false
    
    // Store the text to paste
    private var clipboardText: String?
    
    // Callback for when hotkey is pressed
    var onHotkeyPressed: (() -> Void)?
    
    private init() {}
    
    func setTextToPaste(_ text: String) {
        clipboardText = text
    }
    
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
        
        // Check and request accessibility permissions with proper prompting
        checkAndRequestAccessibilityPermissions { [weak self] granted in
            if granted {
                self?.pasteTextUsingAccessibility()
            } else {
                NSLog("🔥 Cannot paste: Accessibility permissions denied")
                self?.showAccessibilityPermissionAlert()
            }
        }
    }
    
    private func checkAndRequestAccessibilityPermissions(completion: @escaping (Bool) -> Void) {
        NSLog("🔥 Checking accessibility permissions")
        
        // Use the proper API to check and request accessibility permissions
        let options: [CFString: Any] = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true]
        let isTrusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
        
        if isTrusted {
            NSLog("🔥 Accessibility permissions already granted")
            completion(true)
        } else {
            NSLog("🔥 Accessibility permissions requested. Prompt shown.")
            // Add delay to allow prompt to register the app in the system
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.showAccessibilityPermissionAlert { granted in
                    completion(granted)
                }
            }
        }
    }
    
    private func showAccessibilityPermissionAlert(completion: @escaping (Bool) -> Void) {
        NSLog("🔥 Showing accessibility permission alert")
        
        let alert = NSAlert()
        alert.messageText = "Accessibility Permissions Required"
        alert.informativeText = "WolfWhisper needs Accessibility permissions to paste transcribed text into other applications. Please enable it in System Settings > Privacy & Security > Accessibility."
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            // Open System Settings to Accessibility panel
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
                
                // Poll for permission grant after a delay (macOS doesn't notify automatically)
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    let isTrusted = AXIsProcessTrusted()
                    NSLog("🔥 After opening System Settings, trusted: \(isTrusted)")
                    completion(isTrusted)
                }
            } else {
                NSLog("🔥 Failed to open System Settings")
                completion(false)
            }
        } else {
            NSLog("🔥 User cancelled accessibility permission request")
            completion(false)
        }
    }
    
    private func pasteTextUsingAccessibility() {
        NSLog("🔥 pasteTextUsingAccessibility called")
        
        guard let textToPaste = clipboardText else {
            NSLog("🔥 No text to paste")
            return
        }
        
        // Update clipboard as a fallback
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(textToPaste, forType: .string)
        NSLog("🔥 Text copied to clipboard as fallback")
        
        // Get the frontmost application
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication else {
            NSLog("🔥 No frontmost application found")
            showPasteErrorAlert(message: "Cannot paste: No active application found.")
            return
        }
        
        NSLog("🔥 Frontmost app: \(frontmostApp.localizedName ?? "Unknown")")
        
        // Create an Accessibility element for the app
        let appElement = AXUIElementCreateApplication(frontmostApp.processIdentifier)
        
        // Try multiple strategies to find a text input field
        if !tryPasteToFocusedElement(appElement: appElement, text: textToPaste) {
            if !tryPasteToFirstResponder(appElement: appElement, text: textToPaste) {
                if !tryPasteToAnyTextFieldInApp(appElement: appElement, text: textToPaste) {
                    // If all strategies fail, try simulating paste with key events as last resort
                    if !trySimulatePasteKeyEvent(text: textToPaste) {
                        NSLog("🔥 All paste strategies failed")
                        showPasteErrorAlert(message: "Cannot paste: No accessible text field found.")
                    }
                }
            }
        }
    }
    
    private func tryPasteToFocusedElement(appElement: AXUIElement, text: String) -> Bool {
        NSLog("🔥 Trying to paste to focused element")
        
        // Get the focused UI element
        var focusedElement: AnyObject?
        let focusError = AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedElement)
        
        guard focusError == .success, let element = focusedElement else {
            NSLog("🔥 No focused element found: \(focusError.rawValue)")
            return false
        }
        
        let axElement = element as! AXUIElement
        return trySetTextOnElement(axElement, text: text, description: "focused element")
    }
    
    private func tryPasteToFirstResponder(appElement: AXUIElement, text: String) -> Bool {
        NSLog("🔥 Trying to paste to first responder")
        
        // Try to get the main window first
        var mainWindow: AnyObject?
        let windowError = AXUIElementCopyAttributeValue(appElement, kAXMainWindowAttribute as CFString, &mainWindow)
        
        guard windowError == .success, let window = mainWindow else {
            NSLog("🔥 No main window found")
            return false
        }
        
        let axWindow = window as! AXUIElement
        
        // Look for focused element within the main window
        var focusedInWindow: AnyObject?
        let focusInWindowError = AXUIElementCopyAttributeValue(axWindow, kAXFocusedUIElementAttribute as CFString, &focusedInWindow)
        
        guard focusInWindowError == .success, let element = focusedInWindow else {
            NSLog("🔥 No focused element in main window")
            return false
        }
        
        let axElement = element as! AXUIElement
        return trySetTextOnElement(axElement, text: text, description: "first responder in main window")
    }
    
    private func tryPasteToAnyTextFieldInApp(appElement: AXUIElement, text: String) -> Bool {
        NSLog("🔥 Trying to find any text field in the app")
        
        // Get all windows
        var windows: AnyObject?
        let windowsError = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windows)
        
        guard windowsError == .success, let windowArray = windows as? [AXUIElement] else {
            NSLog("🔥 Could not get windows")
            return false
        }
        
        // Search through all windows for text fields
        for window in windowArray {
            if let textField = findTextFieldInElement(window) {
                if trySetTextOnElement(textField, text: text, description: "found text field") {
                    return true
                }
            }
        }
        
        NSLog("🔥 No accessible text fields found in any window")
        return false
    }
    
    private func findTextFieldInElement(_ element: AXUIElement) -> AXUIElement? {
        // Check if this element itself is a text field
        var role: AnyObject?
        let roleError = AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
        
        if roleError == .success, let roleString = role as? String {
            if roleString == kAXTextFieldRole || roleString == kAXTextAreaRole || roleString == kAXComboBoxRole {
                return element
            }
        }
        
        // Recursively search children
        var children: AnyObject?
        let childrenError = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children)
        
        guard childrenError == .success, let childArray = children as? [AXUIElement] else {
            return nil
        }
        
        for child in childArray {
            if let textField = findTextFieldInElement(child) {
                return textField
            }
        }
        
        return nil
    }
    
    private func trySetTextOnElement(_ element: AXUIElement, text: String, description: String) -> Bool {
        NSLog("🔥 Trying to set text on \(description)")
        
        // Check if the element supports the value attribute
        var isSettable = DarwinBoolean(false)
        let settableError = AXUIElementIsAttributeSettable(element, kAXValueAttribute as CFString, &isSettable)
        
        if settableError != .success {
            NSLog("🔥 Could not check if \(description) is settable: \(settableError.rawValue)")
            return false
        }
        
        if !isSettable.boolValue {
            NSLog("🔥 \(description) is not settable")
            return false
        }
        
        // Try to set the text value
        let setError = AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, text as CFTypeRef)
        if setError != .success {
            NSLog("🔥 Failed to set text on \(description): \(setError.rawValue)")
            return false
        }
        
        NSLog("🔥 Successfully pasted text to \(description)")
        return true
    }
    
    private func trySimulatePasteKeyEvent(text: String) -> Bool {
        NSLog("🔥 Trying to simulate paste key event as last resort")
        
        // This is a fallback - simulate Cmd+V after putting text in clipboard
        // Note: This might not work in sandboxed apps, but worth trying
        
        let keyDownEvent = CGEvent(keyboardEventSource: nil, virtualKey: 0x09, keyDown: true) // V key
        let keyUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: 0x09, keyDown: false)
        
        keyDownEvent?.flags = .maskCommand
        keyUpEvent?.flags = .maskCommand
        
        keyDownEvent?.post(tap: .cghidEventTap)
        keyUpEvent?.post(tap: .cghidEventTap)
        
        NSLog("🔥 Simulated Cmd+V key event")
        return true
    }
    
    private func showAccessibilityPermissionAlert() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Accessibility Permissions Required"
            alert.informativeText = "WolfWhisper needs Accessibility permissions to paste transcribed text into other applications. Please enable it in System Settings > Privacy & Security > Accessibility."
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Cancel")
            
            if alert.runModal() == .alertFirstButtonReturn {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }
    
    private func showPasteErrorAlert(message: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Paste Failed"
            alert.informativeText = "\(message) The text has been copied to the clipboard for manual pasting."
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
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