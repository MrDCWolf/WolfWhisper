import SwiftUI
import Carbon

struct SettingsView: View {
    @ObservedObject var appState: AppStateModel
    @State private var selectedTab: SettingsTab = .general
    
    enum SettingsTab: String, CaseIterable {
        case general = "General"
        case audio = "Audio"
        case hotkeys = "Hotkeys"
        case advanced = "Advanced"
        
        var icon: String {
            switch self {
            case .general: return "gear"
            case .audio: return "speaker.wave.2"
            case .hotkeys: return "keyboard"
            case .advanced: return "slider.horizontal.3"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            // Sidebar
            VStack(alignment: .leading, spacing: 0) {
                Text("Settings")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 10)
                
                Divider()
                
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(SettingsTab.allCases, id: \.self) { tab in
                        SettingsTabButton(
                            tab: tab,
                            isSelected: selectedTab == tab,
                            action: { selectedTab = tab }
                        )
                    }
                }
                .padding(.vertical, 8)
                
                Spacer()
                
                // Version info
                VStack(alignment: .leading, spacing: 4) {
                    Divider()
                    HStack {
                        Text("WolfWhisper")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("v1.4.0")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                }
            }
            .frame(width: 200)
            .background(Color.gray.opacity(0.05))
            
            // Content
            Group {
                switch selectedTab {
                case .general:
                    GeneralSettingsView(settings: appState.settings)
                case .audio:
                    AudioSettingsView(settings: appState.settings)
                case .hotkeys:
                    HotkeySettingsView(settings: appState.settings)
                case .advanced:
                    AdvancedSettingsView(settings: appState.settings)
                }
            }
            .frame(minWidth: 500, minHeight: 400)
        }
        .navigationTitle("Settings")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    appState.showSettings = false
                }
                .keyboardShortcut(.defaultAction)
            }
        }
    }
}

struct SettingsTabButton: View {
    let tab: SettingsView.SettingsTab
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: tab.icon)
                    .frame(width: 16)
                    .foregroundColor(isSelected ? .blue : .secondary)
                
                Text(tab.rawValue)
                    .font(.system(.body, weight: isSelected ? .medium : .regular))
                    .foregroundColor(isSelected ? .primary : .secondary)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct GeneralSettingsView: View {
    @ObservedObject var settings: SettingsModel
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SettingsSection(title: "API Configuration") {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("OpenAI API Key")
                                .font(.headline)
                            SecureField("sk-...", text: $settings.apiKey)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .font(.system(.body, design: .monospaced))
                            Text("Your API key is stored securely in the Keychain")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Whisper Model")
                                .font(.headline)
                            Picker("Model", selection: $settings.selectedModel) {
                                ForEach(WhisperModel.allCases, id: \.self) { model in
                                    Text(model.displayName).tag(model)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            Text(settings.selectedModel.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                SettingsSection(title: "Behavior") {
                    VStack(alignment: .leading, spacing: 16) {
                        Toggle("Auto-transcribe after recording", isOn: $settings.autoTranscribe)
                        
                        Toggle("Show in menu bar", isOn: $settings.showInMenuBar)
                        
                        Toggle("Launch at login", isOn: $settings.launchAtLogin)
                    }
                }
            }
            .padding(24)
        }
        .navigationTitle("General")
        .onChange(of: settings.apiKey) { _ in settings.saveSettings() }
        .onChange(of: settings.selectedModel) { _ in settings.saveSettings() }
        .onChange(of: settings.autoTranscribe) { _ in settings.saveSettings() }
        .onChange(of: settings.showInMenuBar) { _ in settings.saveSettings() }
        .onChange(of: settings.launchAtLogin) { _ in settings.saveSettings() }
    }
}

struct AudioSettingsView: View {
    @ObservedObject var settings: SettingsModel
    @State private var inputDevices: [AudioDevice] = []
    @State private var selectedInputDevice: AudioDevice?
    
    struct AudioDevice: Identifiable, Hashable {
        let id: String
        let name: String
        let isDefault: Bool
        
        static let systemDefault = AudioDevice(id: "system_default", name: "System Default", isDefault: true)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SettingsSection(title: "Input Settings") {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Microphone")
                                .font(.headline)
                            Picker("Input Device", selection: $selectedInputDevice) {
                                Text("System Default").tag(AudioDevice.systemDefault as AudioDevice?)
                                if !inputDevices.isEmpty {
                                    Divider()
                                    ForEach(inputDevices.filter { !$0.isDefault }) { device in
                                        Text(device.name).tag(device as AudioDevice?)
                                    }
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            
                            if selectedInputDevice?.isDefault == true {
                                Text("Uses the microphone selected in System Preferences → Sound → Input")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Input Level")
                                .font(.headline)
                            // TODO: Add audio level meter
                            Text("Audio level meter will be displayed here")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                SettingsSection(title: "Recording Quality") {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Sample Rate")
                                .font(.headline)
                            Picker("Sample Rate", selection: .constant("44.1 kHz")) {
                                Text("44.1 kHz (Recommended)").tag("44.1 kHz")
                                Text("48 kHz").tag("48 kHz")
                            }
                            .pickerStyle(MenuPickerStyle())
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Format")
                                .font(.headline)
                            Picker("Format", selection: .constant("M4A")) {
                                Text("M4A (Recommended)").tag("M4A")
                                Text("WAV").tag("WAV")
                            }
                            .pickerStyle(MenuPickerStyle())
                        }
                    }
                }
            }
            .padding(24)
        }
        .navigationTitle("Audio")
        .onAppear {
            loadAudioDevices()
            // Set system default if no device is selected
            if selectedInputDevice == nil {
                selectedInputDevice = AudioDevice.systemDefault
            }
        }
        .onChange(of: selectedInputDevice) { _ in
            // Save the selected device (for now we'll just use system default)
            settings.saveSettings()
        }
    }
    
    private func loadAudioDevices() {
        // Load actual audio input devices (simplified for now)
        inputDevices = [
            AudioDevice(id: "builtin", name: "Built-in Microphone", isDefault: false),
            AudioDevice(id: "external", name: "External Microphone", isDefault: false)
        ]
        // Always default to system default
        selectedInputDevice = AudioDevice.systemDefault
    }
}

struct HotkeySettingsView: View {
    @ObservedObject var settings: SettingsModel
    @State private var isRecordingHotkey = false
    @State private var presetHotkeys = [
        ("⌘⇧D", "Command + Shift + D"),
        ("⌘⇧V", "Command + Shift + V"),
        ("⌘⇧T", "Command + Shift + T"),
        ("⌘⇧R", "Command + Shift + R"),
        ("⌃⇧Space", "Control + Shift + Space"),
        ("⌥⇧D", "Option + Shift + D")
    ]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SettingsSection(title: "Global Hotkey") {
                    VStack(alignment: .leading, spacing: 16) {
                        Toggle("Enable global hotkey", isOn: $settings.hotkeyEnabled)
                        
                        if settings.hotkeyEnabled {
                                                    VStack(alignment: .leading, spacing: 8) {
                            Text("Hotkey Combination")
                                .font(.headline)
                            
                            Text("Current: \(settings.hotkeyDisplay)")
                                .font(.system(.body, design: .monospaced))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(6)
                            
                            Text("Choose a preset:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.top, 8)
                            
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 8) {
                                ForEach(Array(presetHotkeys.enumerated()), id: \.offset) { index, preset in
                                    Button(action: {
                                        setHotkey(preset.0)
                                    }) {
                                        VStack(spacing: 4) {
                                            Text(preset.0)
                                                .font(.system(.title3, design: .monospaced))
                                                .fontWeight(.medium)
                                            Text(preset.1)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .padding(.horizontal, 8)
                                        .background(settings.hotkeyDisplay == preset.0 ? Color.blue.opacity(0.2) : Color.gray.opacity(0.1))
                                        .cornerRadius(8)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(settings.hotkeyDisplay == preset.0 ? Color.blue : Color.clear, lineWidth: 2)
                                        )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            
                            Text("Or record your own:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.top, 16)
                            
                            Button(action: {
                                isRecordingHotkey.toggle()
                            }) {
                                HStack {
                                    Image(systemName: isRecordingHotkey ? "stop.circle" : "record.circle")
                                        .foregroundColor(isRecordingHotkey ? .red : .blue)
                                    
                                    if isRecordingHotkey {
                                        Text("Press your desired key combination...")
                                            .foregroundColor(.blue)
                                    } else {
                                        Text("Record Custom Hotkey")
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 16)
                                .background(isRecordingHotkey ? Color.red.opacity(0.1) : Color.blue.opacity(0.1))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(isRecordingHotkey ? Color.red : Color.blue, lineWidth: 2)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            .onKeyPress { keyPress in
                                if isRecordingHotkey {
                                    recordKeyPress(keyPress)
                                    return .handled
                                }
                                return .ignored
                            }
                            }
                        }
                    }
                }
                
                SettingsSection(title: "Hotkey Behavior") {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Action")
                                .font(.headline)
                            Picker("Action", selection: .constant("dictate")) {
                                Text("Start/Stop Dictation").tag("dictate")
                                Text("Push-to-Talk").tag("ptt")
                            }
                            .pickerStyle(MenuPickerStyle())
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("After Transcription")
                                .font(.headline)
                            Picker("After Transcription", selection: .constant("paste")) {
                                Text("Copy to clipboard and paste").tag("paste")
                                Text("Copy to clipboard only").tag("copy")
                                Text("Show in app").tag("show")
                            }
                            .pickerStyle(MenuPickerStyle())
                        }
                    }
                }
            }
            .padding(24)
        }
        .navigationTitle("Hotkeys")
        .onChange(of: settings.hotkeyEnabled) { _ in settings.saveSettings() }
    }
    
    private func setHotkey(_ hotkeyString: String) {
        let (modifiers, key) = parseHotkeyString(hotkeyString)
        settings.hotkeyModifiers = modifiers
        settings.hotkeyKey = key
        settings.saveSettings()
    }
    
    private func parseHotkeyString(_ hotkeyString: String) -> (String, String) {
        var modifiers = ""
        
        // Parse modifiers
        if hotkeyString.contains("⌘") {
            modifiers += "⌘"
        }
        if hotkeyString.contains("⌃") {
            modifiers += "⌃"
        }
        if hotkeyString.contains("⌥") {
            modifiers += "⌥"
        }
        if hotkeyString.contains("⇧") {
            modifiers += "⇧"
        }
        
        // Parse key
        let keyChar = hotkeyString.replacingOccurrences(of: "⌘", with: "")
            .replacingOccurrences(of: "⌃", with: "")
            .replacingOccurrences(of: "⌥", with: "")
            .replacingOccurrences(of: "⇧", with: "")
            .trimmingCharacters(in: .whitespaces)
        
        let key = keyChar.uppercased()
        
        return (modifiers, key)
    }
    
    private func recordKeyPress(_ keyPress: KeyPress) {
        var modifiers = ""
        var key = ""
        
        // Capture modifiers
        if keyPress.modifiers.contains(.command) {
            modifiers += "⌘"
        }
        if keyPress.modifiers.contains(.control) {
            modifiers += "⌃"
        }
        if keyPress.modifiers.contains(.option) {
            modifiers += "⌥"
        }
        if keyPress.modifiers.contains(.shift) {
            modifiers += "⇧"
        }
        
        // Capture key
        key = keyPress.key.character.uppercased()
        
        // Set the new hotkey
        let hotkeyString = "\(modifiers)\(key)"
        setHotkey(hotkeyString)
        
        // Stop recording
        isRecordingHotkey = false
    }
}

struct AdvancedSettingsView: View {
    @ObservedObject var settings: SettingsModel
    @State private var showingResetAlert = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SettingsSection(title: "Privacy & Data") {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Data Handling")
                                .font(.headline)
                            Text("Audio recordings are sent to OpenAI for transcription and are not stored locally or by OpenAI beyond the duration of the API call.")
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Temporary Files")
                                .font(.headline)
                            HStack {
                                Text("Audio files are temporarily stored in:")
                                    .font(.body)
                                Spacer()
                                Button("Open Folder") {
                                    // TODO: Open temp folder
                                }
                                .font(.caption)
                            }
                            Text(FileManager.default.temporaryDirectory.path)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                SettingsSection(title: "Troubleshooting") {
                    VStack(alignment: .leading, spacing: 16) {
                        Button("Reset All Settings") {
                            showingResetAlert = true
                        }
                        .foregroundColor(.red)
                        
                        Button("Export Debug Log") {
                            // TODO: Export debug information
                        }
                        
                        Button("Check Permissions") {
                            // TODO: Re-check all permissions
                        }
                    }
                }
                
                SettingsSection(title: "About") {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Version:")
                            Spacer()
                            Text("1.4.0")
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Build:")
                            Spacer()
                            Text("2024.01")
                                .foregroundColor(.secondary)
                        }
                        
                        Link("View on GitHub", destination: URL(string: "https://github.com/MrDCWolf/WolfWhisper")!)
                        
                        Link("Report Issue", destination: URL(string: "https://github.com/MrDCWolf/WolfWhisper/issues")!)
                    }
                }
            }
            .padding(24)
        }
        .navigationTitle("Advanced")
        .alert("Reset Settings", isPresented: $showingResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                resetAllSettings()
            }
        } message: {
            Text("This will reset all settings to their default values. This action cannot be undone.")
        }
    }
    
    private func resetAllSettings() {
        // Reset UserDefaults
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "selectedModel")
        defaults.removeObject(forKey: "hotkeyEnabled")
        defaults.removeObject(forKey: "hotkeyModifiers")
        defaults.removeObject(forKey: "hotkeyKey")
        defaults.removeObject(forKey: "autoTranscribe")
        defaults.removeObject(forKey: "showInMenuBar")
        defaults.removeObject(forKey: "launchAtLogin")
        defaults.removeObject(forKey: "hasCompletedOnboarding")
        
        // Clear keychain
        KeychainService.shared.deleteApiKey()
        
        // Reload settings
        settings.loadSettings()
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3)
                .fontWeight(.semibold)
            
            content
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
} 