import SwiftUI
import Carbon
import CoreGraphics

struct SettingsView: View {
    @ObservedObject var appState: AppState
    @State private var selectedTab: SettingsTab = .general
    
    enum SettingsTab: String, CaseIterable {
        case general = "General"
        case hotkeys = "Hotkeys"
        case advanced = "Advanced"
        
        var icon: String {
            switch self {
            case .general: return "gear"
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
                            ModernGeneralSettingsView(appState: appState)
                        case .hotkeys:
                            ModernHotkeySettingsView(appState: appState)
                        case .advanced:
                            ModernAdvancedSettingsView(appState: appState)
                        }
                    }
                    .frame(minWidth: 500, minHeight: 400)
                }
            }
            .padding(20)
        }
        .onDisappear {
            Task {
                await appState.saveSettings()
            }
        }
    }
}

struct ModernGeneralSettingsView: View {
    @ObservedObject var appState: AppState
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ModernSettingsSection(title: "Transcription Provider") {
                    VStack(alignment: .leading, spacing: 16) {
                        ModernSettingsField(
                            title: "Provider",
                            description: appState.selectedProvider.description
                        ) {
                            Picker("Provider", selection: $appState.selectedProvider) {
                                ForEach(TranscriptionProvider.allCases, id: \.self) { provider in
                                    Text(provider.displayName).tag(provider)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .tint(.primary)
                        }
                        
                        if appState.selectedProvider == .openAI {
                            ModernSettingsField(
                                title: "OpenAI API Key",
                                description: "Your API key is stored securely in the Keychain"
                            ) {
                                SecureField("sk-...", text: $appState.openAIAPIKey)
                                    .textFieldStyle(ModernTextFieldStyle())
                                    .font(.system(.body, design: .monospaced))
                            }
                            
                            ModernSettingsField(
                                title: "Whisper Model",
                                description: "Select the OpenAI model to use."
                            ) {
                                Picker("Model", selection: $appState.selectedOpenAIModel) {
                                    ForEach(TranscriptionProvider.openAI.models, id: \.self) { model in
                                        Text(model).tag(model)
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                                .tint(.primary)
                            }
                        }
                        
                        if appState.selectedProvider == .gemini {
                            ModernSettingsField(
                                title: "Google AI API Key",
                                description: "Your API key is stored securely in the Keychain"
                            ) {
                                SecureField("AIza...", text: $appState.geminiAPIKey)
                                    .textFieldStyle(ModernTextFieldStyle())
                                    .font(.system(.body, design: .monospaced))
                            }
                            
                            ModernSettingsField(
                                title: "Gemini Model",
                                description: "Select the Google model to use."
                            ) {
                                Picker("Model", selection: $appState.selectedGeminiModel) {
                                    ForEach(TranscriptionProvider.gemini.models, id: \.self) { model in
                                        Text(model).tag(model)
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                                .tint(.primary)
                            }
                        }
                    }
                }
                
                ModernSettingsSection(title: "Behavior") {
                    VStack(alignment: .leading, spacing: 16) {
                        ModernToggle(
                            title: "Show in menu bar",
                            isOn: $appState.showInMenuBar
                        )
                        
                        ModernToggle(
                            title: "Launch at login",
                            isOn: $appState.launchAtLogin
                        )
                    }
                }
            }
            .padding(20)
        }
        .onDisappear {
            Task {
                await appState.saveSettings()
            }
        }
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

struct ModernHotkeySettingsView: View {
    @ObservedObject var appState: AppState
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ModernSettingsSection(title: "Global Hotkey") {
                    VStack(alignment: .leading, spacing: 16) {
                        ModernToggle(
                            title: "Enable global hotkey",
                            isOn: $appState.hotkeyEnabled
                        )
                        
                        ModernSettingsField(
                            title: "Hotkey Combination",
                            description: "Set the key combination to trigger recording."
                        ) {
                            HotkeyRecorderField(
                                hotkeyDisplay: $appState.hotkeyDisplay,
                                hotkeyModifiers: $appState.hotkeyModifiers,
                                hotkeyKey: $appState.hotkeyKey
                            )
                        }
                    }
                }
            }
            .padding(20)
        }
        .onDisappear {
            Task {
                await appState.saveSettings()
            }
        }
    }
}

struct ModernAdvancedSettingsView: View {
    @ObservedObject var appState: AppState
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ModernSettingsSection(title: "Placeholder") {
                    Text("Advanced settings will be available in a future version.")
                        .foregroundColor(.secondary)
                }
            }
            .padding(20)
        }
        .onDisappear {
            Task {
                await appState.saveSettings()
            }
        }
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





