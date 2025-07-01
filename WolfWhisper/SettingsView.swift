import SwiftUI
import Carbon
import CoreGraphics

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
        ZStack {
            // Premium background matching main app
            GeometryReader { geometry in
                ZStack {
                    // Base gradient background
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.4, green: 0.6, blue: 0.8).opacity(0.3),
                            Color(red: 0.8, green: 0.6, blue: 0.4).opacity(0.3),
                            Color(red: 0.5, green: 0.8, blue: 0.6).opacity(0.3)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    
                    // Overlay blur effect
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .opacity(0.8)
                }
                .ignoresSafeArea()
            }
            
            NavigationSplitView {
                // Modern Sidebar
                ModernSidebar(
                    selectedTab: $selectedTab,
                    onTabChange: { tab in selectedTab = tab }
                )
                .frame(width: 220)
                .navigationSplitViewColumnWidth(220)
            } detail: {
                // Modern Content
                ZStack {
                    // Content background
                    Rectangle()
                        .fill(.thinMaterial)
                        .ignoresSafeArea()
                    
                    Group {
                        switch selectedTab {
                        case .general:
                            ModernGeneralSettingsView(settings: appState.settings)
                        case .audio:
                            ModernAudioSettingsView(settings: appState.settings)
                        case .hotkeys:
                            ModernHotkeySettingsView(settings: appState.settings)
                        case .advanced:
                            ModernAdvancedSettingsView(settings: appState.settings)
                        }
                    }
                    .frame(minWidth: 500, minHeight: 400)
                }
            }
        }
    }
}



struct ModernGeneralSettingsView: View {
    @ObservedObject var settings: SettingsModel
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ModernSettingsSection(title: "API Configuration") {
                    VStack(alignment: .leading, spacing: 16) {
                        ModernSettingsField(
                            title: "OpenAI API Key",
                            description: "Your API key is stored securely in the Keychain"
                        ) {
                            SecureField("sk-...", text: $settings.apiKey)
                                .textFieldStyle(ModernTextFieldStyle())
                                .font(.system(.body, design: .monospaced))
                        }
                        
                        ModernSettingsField(
                            title: "Whisper Model",
                            description: settings.selectedModel.description
                        ) {
                            Picker("Model", selection: $settings.selectedModel) {
                                ForEach(WhisperModel.allCases, id: \.self) { model in
                                    Text(model.displayName).tag(model)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .tint(.primary)
                        }
                    }
                }
                
                ModernSettingsSection(title: "Behavior") {
                    VStack(alignment: .leading, spacing: 16) {
                        ModernToggle(
                            title: "Auto-transcribe after recording",
                            isOn: $settings.autoTranscribe
                        )
                        
                        ModernToggle(
                            title: "Show in menu bar",
                            isOn: $settings.showInMenuBar
                        )
                        
                        ModernToggle(
                            title: "Launch at login",
                            isOn: $settings.launchAtLogin
                        )
                    }
                }
            }
            .padding(20)
        }

        .onChange(of: settings.apiKey) { _, _ in settings.saveSettings() }
        .onChange(of: settings.selectedModel) { _, _ in settings.saveSettings() }
        .onChange(of: settings.autoTranscribe) { _, _ in settings.saveSettings() }
        .onChange(of: settings.showInMenuBar) { _, _ in settings.saveSettings() }
        .onChange(of: settings.launchAtLogin) { _, _ in settings.saveSettings() }
    }
}

struct ModernSettingsField<Content: View>: View {
    let title: String
    let description: String?
    let content: Content
    
    init(title: String, description: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.description = description
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(.primary)
            
            content
            
            if let description = description {
                Text(description)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct ModernToggle: View {
    let title: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(.primary)
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .toggleStyle(SwitchToggleStyle(tint: .blue))
        }
    }
}

struct ModernTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.white.opacity(0.3), lineWidth: 1)
            )
    }
}

struct ModernAudioSettingsView: View {
    @ObservedObject var settings: SettingsModel
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ModernSettingsSection(title: "Input Settings") {
                    VStack(alignment: .leading, spacing: 16) {
                        ModernSettingsField(
                            title: "Microphone",
                            description: "Uses the microphone selected in System Preferences → Sound → Input"
                        ) {
                            Text("System Default")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(.white.opacity(0.3), lineWidth: 1)
                                )
                        }
                    }
                }
                
                ModernSettingsSection(title: "Recording Quality") {
                    VStack(alignment: .leading, spacing: 16) {
                        ModernSettingsField(
                            title: "Sample Rate"
                        ) {
                            Text("44.1 kHz (Recommended)")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(.white.opacity(0.3), lineWidth: 1)
                                )
                        }
                        
                        ModernSettingsField(
                            title: "Format"
                        ) {
                            Text("M4A (Recommended)")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(.white.opacity(0.3), lineWidth: 1)
                                )
                        }
                    }
                }
            }
            .padding(20)
        }

    }
}

struct ModernHotkeySettingsView: View {
    @ObservedObject var settings: SettingsModel
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ModernSettingsSection(title: "Global Hotkey") {
                    VStack(alignment: .leading, spacing: 16) {
                        ModernToggle(
                            title: "Enable global hotkey",
                            isOn: $settings.hotkeyEnabled
                        )
                        
                        if settings.hotkeyEnabled {
                            ModernSettingsField(
                                title: "Current Hotkey",
                                description: "Click Record to set a new hotkey combination"
                            ) {
                                HotkeyRecorderField(
                                    hotkeyDisplay: $settings.hotkeyDisplay,
                                    hotkeyModifiers: $settings.hotkeyModifiers,
                                    hotkeyKey: $settings.hotkeyKey
                                )
                                .frame(width: 220, height: 40)
                            }
                        }
                    }
                }
                
                if settings.hotkeyEnabled {
                    ModernSettingsSection(title: "Hotkey Behavior") {
                        VStack(alignment: .leading, spacing: 16) {
                            ModernSettingsField(
                                title: "After Transcription",
                                description: "What happens when transcription is complete"
                            ) {
                                Text("Copy to clipboard and paste")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(.white.opacity(0.3), lineWidth: 1)
                                    )
                            }
                        }
                    }
                }
            }
            .padding(20)
        }

        .onChange(of: settings.hotkeyEnabled) { _, _ in settings.saveSettings() }
    }
}

struct ModernAdvancedSettingsView: View {
    @ObservedObject var settings: SettingsModel
    @State private var showingResetAlert = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ModernSettingsSection(title: "Privacy & Data") {
                    VStack(alignment: .leading, spacing: 16) {
                        ModernSettingsField(
                            title: "Data Handling",
                            description: "Audio recordings are sent to OpenAI for transcription and are not stored locally or by OpenAI beyond the duration of the API call."
                        ) {
                            EmptyView()
                        }
                        
                        ModernSettingsField(
                            title: "Temporary Files",
                            description: "Audio files are temporarily stored during processing"
                        ) {
                            Text(FileManager.default.temporaryDirectory.path)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
                        }
                    }
                }
                
                ModernSettingsSection(title: "Troubleshooting") {
                    VStack(alignment: .leading, spacing: 12) {
                        ModernActionButton(
                            title: "Reset All Settings",
                            style: .destructive
                        ) {
                            showingResetAlert = true
                        }
                        
                        ModernActionButton(
                            title: "Export Debug Log",
                            style: .secondary
                        ) {
                            // TODO: Export debug information
                        }
                        
                        ModernActionButton(
                            title: "Check Permissions",
                            style: .secondary
                        ) {
                            // TODO: Re-check all permissions
                        }
                    }
                }
                
                ModernSettingsSection(title: "About") {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Version:")
                                .font(.system(size: 16, weight: .medium))
                            Spacer()
                            Text("1.4.0")
                                .font(.system(size: 16, weight: .regular))
                                .foregroundStyle(.secondary)
                        }
                        
                        HStack {
                            Text("Build:")
                                .font(.system(size: 16, weight: .medium))
                            Spacer()
                            Text("2024.01")
                                .font(.system(size: 16, weight: .regular))
                                .foregroundStyle(.secondary)
                        }
                        
                        Divider()
                            .background(.white.opacity(0.2))
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Link("View on GitHub", destination: URL(string: "https://github.com/MrDCWolf/WolfWhisper")!)
                                .font(.system(size: 16, weight: .medium))
                            
                            Link("Report Issue", destination: URL(string: "https://github.com/MrDCWolf/WolfWhisper/issues")!)
                                .font(.system(size: 16, weight: .medium))
                        }
                    }
                }
            }
            .padding(20)
        }

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
        defaults.removeObject(forKey: "hotkeyDisplay")
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

struct ModernActionButton: View {
    let title: String
    let style: ButtonStyle
    let action: () -> Void
    
    enum ButtonStyle {
        case primary, secondary, destructive
        
        var foregroundColor: Color {
            switch self {
            case .primary: return .white
            case .secondary: return .primary
            case .destructive: return .red
            }
        }
        
        var backgroundColor: Color {
            switch self {
            case .primary: return .blue
            case .secondary: return .clear
            case .destructive: return .clear
            }
        }
    }
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(style.foregroundColor)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(style.backgroundColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(style.foregroundColor.opacity(0.2), lineWidth: 1)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ModernSettingsSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
            
            content
        }
        .padding(20)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 3)
    }
}

struct ModernSidebar: View {
    @Binding var selectedTab: SettingsView.SettingsTab
    let onTabChange: (SettingsView.SettingsTab) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    // Wolf icon
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 36, height: 36)
                            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 1)
                        
                        Image(systemName: "pawprint.circle.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(.white)
                            .symbolRenderingMode(.hierarchical)
                    }
                    
                    Text("Settings")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
            
            // Navigation tabs
            VStack(alignment: .leading, spacing: 6) {
                ForEach(SettingsView.SettingsTab.allCases, id: \.self) { tab in
                    ModernSidebarTab(
                        tab: tab,
                        isSelected: selectedTab == tab,
                        action: { 
                            selectedTab = tab
                            onTabChange(tab)
                        }
                    )
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 20)
            
            Spacer()
            
            // Version info in modern style
            VStack(alignment: .leading, spacing: 8) {
                Rectangle()
                    .fill(.white.opacity(0.1))
                    .frame(height: 1)
                    .padding(.horizontal, 20)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("WolfWhisper")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                    Text("Version 1.4.0")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .background(.ultraThinMaterial)
    }
}

struct ModernSidebarTab: View {
    let tab: SettingsView.SettingsTab
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: tab.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(isSelected ? .blue : .secondary)
                    .frame(width: 20)
                
                Text(tab.rawValue)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(isSelected ? .blue : .primary)
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.blue.opacity(0.15))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(.blue.opacity(0.3), lineWidth: 1)
                            )
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.clear)
                    }
                }
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .focusable(false)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}



