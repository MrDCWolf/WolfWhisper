import SwiftUI
import Carbon

struct HotkeyRecorderField: View {
    @Binding var hotkeyDisplay: String
    @Binding var hotkeyModifiers: UInt
    @Binding var hotkeyKey: UInt16
    @State private var isRecording = false
    @State private var globalEventMonitor: Any?
    @State private var localEventMonitor: Any?
    @FocusState private var isFieldFocused: Bool
    
    var body: some View {
        HStack {
            Text(isRecording ? "Press Key Combination..." : (hotkeyDisplay.isEmpty ? "None" : hotkeyDisplay))
                .foregroundColor(isRecording ? .secondary : .primary)
                .frame(minWidth: 120, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isRecording ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: isRecording ? 2 : 1)
                )
                .focused($isFieldFocused)
                .onTapGesture {
                    if !isRecording {
                        startRecording()
                    }
                }
            
            Spacer()
            
            Button(isRecording ? "Stop" : "Record") {
                if isRecording {
                    stopRecording()
                } else {
                    startRecording()
                }
            }
            .buttonStyle(.bordered)
        }
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(6)
        .onDisappear {
            stopRecording()
        }
    }
    
    private func startRecording() {
        print("🎯 Starting hotkey recording...")
        isRecording = true
        isFieldFocused = true
        
        // Monitor global events (when app is not focused)
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { event in
            print("🌍 Global event: keyCode=\(event.keyCode), modifiers=\(event.modifierFlags)")
            handleNSEvent(event)
        }
        
        // Monitor local events (when app is focused)
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            print("🏠 Local event: keyCode=\(event.keyCode), modifiers=\(event.modifierFlags)")
            handleNSEvent(event)
            return nil // Consume the event
        }
    }
    
    private func stopRecording() {
        print("🛑 Stopping hotkey recording...")
        isRecording = false
        isFieldFocused = false
        
        if let monitor = globalEventMonitor {
            NSEvent.removeMonitor(monitor)
            globalEventMonitor = nil
        }
        
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
            localEventMonitor = nil
        }
    }
    
    private func handleNSEvent(_ event: NSEvent) {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let keyCode = event.keyCode
        
        print("🔍 Processing NSEvent: keyCode=\(keyCode), modifiers=\(modifiers)")
        
        // Only capture combinations with at least one modifier
        if !modifiers.isEmpty && keyCode != 0 {
            let modifierFlags = convertModifiersToUInt(modifiers)
            captureHotkey(modifiers: modifierFlags, keyCode: keyCode)
        } else {
            print("⚠️ Ignoring event - no modifiers or invalid keyCode")
        }
    }
    
    private func captureHotkey(modifiers: UInt, keyCode: UInt16) {
        let displayString = createDisplayString(modifiers: modifiers, keyCode: keyCode)
        
        print("✅ Captured hotkey: modifiers=\(modifiers), keyCode=\(keyCode), display=\(displayString)")
        
        DispatchQueue.main.async {
            self.hotkeyModifiers = modifiers
            self.hotkeyKey = keyCode
            self.hotkeyDisplay = displayString
            
            // Auto-stop recording after capture
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.stopRecording()
            }
        }
    }
    
    private func convertModifiersToUInt(_ modifiers: NSEvent.ModifierFlags) -> UInt {
        var result: UInt = 0
        
        if modifiers.contains(.command) {
            result |= UInt(cmdKey)
        }
        if modifiers.contains(.option) {
            result |= UInt(optionKey)
        }
        if modifiers.contains(.control) {
            result |= UInt(controlKey)
        }
        if modifiers.contains(.shift) {
            result |= UInt(shiftKey)
        }
        
        return result
    }
    
    private func createDisplayString(modifiers: UInt, keyCode: UInt16) -> String {
        var result = ""
        
        if modifiers & UInt(controlKey) != 0 {
            result += "⌃"
        }
        if modifiers & UInt(optionKey) != 0 {
            result += "⌥"
        }
        if modifiers & UInt(shiftKey) != 0 {
            result += "⇧"
        }
        if modifiers & UInt(cmdKey) != 0 {
            result += "⌘"
        }
        
        // Convert key code to character
        result += keyCodeToString(keyCode)
        
        return result
    }
    
    private func keyCodeToString(_ keyCode: UInt16) -> String {
        switch keyCode {
        case 0x00: return "A"
        case 0x0B: return "B"
        case 0x08: return "C"
        case 0x02: return "D"
        case 0x0E: return "E"
        case 0x03: return "F"
        case 0x05: return "G"
        case 0x04: return "H"
        case 0x22: return "I"
        case 0x26: return "J"
        case 0x28: return "K"
        case 0x25: return "L"
        case 0x2E: return "M"
        case 0x2D: return "N"
        case 0x1F: return "O"
        case 0x23: return "P"
        case 0x0C: return "Q"
        case 0x0F: return "R"
        case 0x01: return "S"
        case 0x11: return "T"
        case 0x20: return "U"
        case 0x09: return "V"
        case 0x0D: return "W"
        case 0x07: return "X"
        case 0x10: return "Y"
        case 0x06: return "Z"
        case 0x1D: return "0"
        case 0x12: return "1"
        case 0x13: return "2"
        case 0x14: return "3"
        case 0x15: return "4"
        case 0x17: return "5"
        case 0x16: return "6"
        case 0x1A: return "7"
        case 0x1C: return "8"
        case 0x19: return "9"
        case 0x31: return "Space"
        case 0x24: return "Return"
        case 0x30: return "Tab"
        case 0x33: return "Delete"
        case 0x35: return "Escape"
        case 0x7E: return "↑"
        case 0x7D: return "↓"
        case 0x7B: return "←"
        case 0x7C: return "→"
        case 0x7A: return "F1"
        case 0x78: return "F2"
        case 0x63: return "F3"
        case 0x76: return "F4"
        case 0x60: return "F5"
        case 0x61: return "F6"
        case 0x62: return "F7"
        case 0x64: return "F8"
        case 0x65: return "F9"
        case 0x6D: return "F10"
        case 0x67: return "F11"
        case 0x6F: return "F12"
        default: return "Unknown(\(keyCode))"
        }
    }
} 