import SwiftUI
import AppKit
import ServiceManagement

// Custom panel class for draggable floating window
class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    
    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: [.nonactivatingPanel, .fullSizeContentView], backing: backingStoreType, defer: flag)
        
        // Configure panel properties
        self.level = .statusBar // Use .statusBar to be above all windows
        self.collectionBehavior = [.canJoinAllSpaces, .stationary]
        self.isOpaque = false
        self.backgroundColor = NSColor.clear
        self.hasShadow = true
        self.isMovable = true
        self.isMovableByWindowBackground = true  // Allow dragging by clicking anywhere on the window
        self.hidesOnDeactivate = false
        self.ignoresMouseEvents = false
    }
}

// Custom window class that doesn't steal focus (for settings window)
class NonFocusingWindow: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Force cleanup of all services
        AudioService.shared.forceCleanup()
        HotkeyService.shared.unregisterHotkey()
        return false // Do NOT quit the app when the last window closes
    }
}

@main
struct WolfWhisperApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppStateModel()
    @State private var floatingRecordingWindow: NSWindow?
    @State private var floatingWindowDelegate: FloatingWindowDelegate?
    @State private var notificationObserver: NSObjectProtocol?
    
    var body: some Scene {
        WindowGroup {
            if appState.isFirstLaunch {
                OnboardingView(appState: appState)
            } else {
                ContentView(appState: appState)
            }
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(after: .newItem) {
                SettingsMenuButton()
            }
        }
        .onChange(of: appState.currentState) { _, newValue in
            handleStateChange(newValue)
        }
        .onChange(of: appState.settings.launchAtLogin) { _, newValue in
            handleLaunchAtLoginChange(newValue)
        }
        
        // Settings window as a separate scene
        WindowGroup("Settings", id: "settings") {
            SettingsView(appState: appState)
                .frame(minWidth: 490, minHeight: 350)
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        .handlesExternalEvents(matching: Set(arrayLiteral: "settings"))
        
        // Menu Bar Extra - Using isolated content view to prevent constant updates
        MenuBarExtra("WolfWhisper", systemImage: "pawprint.circle.fill") {
            MenuBarContentView(
                currentState: appState.currentState,
                audioLevels: appState.audioLevels,
                statusText: appState.statusText,
                hotkeyDisplay: appState.settings.hotkeyDisplay,
                showInMenuBar: appState.settings.showInMenuBar,
                onStartRecording: {
                    Task { await appState.startRecordingFromMenuBar() }
                },
                onStopRecording: {
                    Task {
                        do {
                            let audioData = try await AudioService.shared.stopRecording()
                            await MainActor.run {
                                appState.updateState(to: .transcribing)
                            }
                            // Transcribe the audio
                            try await TranscriptionService.shared.transcribe(
                                audioData: audioData,
                                apiKey: appState.settings.apiKey,
                                model: appState.settings.selectedModel.rawValue
                            )
                        } catch {
                            await MainActor.run {
                                appState.updateState(to: .idle, message: "Failed to process recording: \(error.localizedDescription)")
                            }
                        }
                    }
                },
                onQuit: {
                    NSApplication.shared.terminate(nil)
                }
            )
        }
        .menuBarExtraStyle(.window)
    }
    
    private func handleStateChange(_ newState: AppState) {
        switch newState {
        case .recording, .transcribing:
            // Always destroy and recreate the floating window for recording/transcribing states
            cleanupFloatingWindow()
            showFloatingRecordingWindow()
        case .idle:
            // Don't destroy the window immediately on .idle
            // Let FloatingRecordingView handle its own cleanup after clipboard animation
            break
        }
    }
    
    private func showFloatingRecordingWindow() {
        // Always clean up existing window first
        if floatingRecordingWindow != nil {
            cleanupFloatingWindow()
        }
        
        // Create fresh window every time
        let recordingView = FloatingRecordingView(appState: appState)
            .id(appState.currentState)
        let hostingController = NSHostingController(rootView: recordingView)
        
        // Create borderless floating panel
        floatingRecordingWindow = FloatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 240),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        // Configure as transparent, borderless window
        floatingRecordingWindow?.backgroundColor = NSColor.clear
        floatingRecordingWindow?.isOpaque = false
        floatingRecordingWindow?.hasShadow = true
        floatingRecordingWindow?.contentView?.wantsLayer = true
        
        floatingRecordingWindow?.contentViewController = hostingController
        floatingRecordingWindow?.isReleasedWhenClosed = false
        
        // Handle window close
        floatingWindowDelegate = FloatingWindowDelegate(appState: appState)
        floatingRecordingWindow?.delegate = floatingWindowDelegate
        
        // Set up NotificationCenter observer (remove old one first if exists)
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        
        notificationObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("CloseFloatingWindow"),
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                self.hideFloatingRecordingWindow()
            }
        }
        
        // Center the window on the main screen
        if let screen = NSScreen.main, let window = floatingRecordingWindow {
            let screenFrame = screen.visibleFrame
            let windowSize = window.frame.size
            let origin = NSPoint(
                x: screenFrame.midX - windowSize.width / 2,
                y: screenFrame.midY - windowSize.height / 2
            )
            window.setFrameOrigin(origin)
        }
        
        // Initial scale for appearance animation
        floatingRecordingWindow?.setFrame(
            NSRect(x: floatingRecordingWindow?.frame.origin.x ?? 0,
                   y: floatingRecordingWindow?.frame.origin.y ?? 0,
                   width: 324,
                   height: 216),
            display: false
        )
        floatingRecordingWindow?.alphaValue = 0.0
        
        // Animate appearance
        floatingRecordingWindow?.orderFront(nil)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            
            floatingRecordingWindow?.animator().alphaValue = 1.0
            floatingRecordingWindow?.animator().setFrame(
                NSRect(x: floatingRecordingWindow?.frame.origin.x ?? 0,
                       y: floatingRecordingWindow?.frame.origin.y ?? 0,
                       width: 360,
                       height: 240),
                display: true
            )
        }
    }
    
    private func cleanupFloatingWindow() {
        // Force remove any active animations/timers in the view
        if let hostingController = floatingRecordingWindow?.contentViewController as? NSHostingController<FloatingRecordingView> {
            hostingController.rootView = FloatingRecordingView(appState: AppStateModel()) // Reset with dummy state
        }
        
        // Remove notification observer
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
            notificationObserver = nil
        }

        // Force hide before close to ensure proper cleanup
        floatingRecordingWindow?.orderOut(nil)
        
        // Close window if it exists
        if floatingRecordingWindow != nil {
            floatingRecordingWindow?.close()
        }

        // Clear references
        floatingRecordingWindow = nil
        floatingWindowDelegate = nil
    }
    
    private func hideFloatingRecordingWindow() {
        guard let window = floatingRecordingWindow else { return }
        
        // Animate dismissal
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            
            window.animator().alphaValue = 0.0
            window.animator().setFrame(
                window.frame.applying(CGAffineTransform(scaleX: 0.9, y: 0.9)),
                display: true
            )
        }) {
            Task { @MainActor in
                // Use the cleanup method to ensure everything is properly cleared
                self.cleanupFloatingWindow()
            }
        }
    }
    
    private func handleLaunchAtLoginChange(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to \(enabled ? "register" : "unregister") launch at login: \(error)")
        }
    }
}

class FloatingWindowDelegate: NSObject, NSWindowDelegate {
    let appState: AppStateModel
    
    init(appState: AppStateModel) {
        self.appState = appState
    }
    
    func windowWillClose(_ notification: Notification) {
        // Stop recording if window is closed manually
        if appState.currentState == .recording {
            // This will be handled by the ContentView's stopRecording method
        }
        
        // Post notification to clean up
        NotificationCenter.default.post(name: NSNotification.Name("CloseFloatingWindow"), object: nil)
    }
}

struct SettingsMenuButton: View {
    @Environment(\.openWindow) private var openWindow
    
    var body: some View {
        Button("Settings...") {
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: "settings")
        }
        .keyboardShortcut(",", modifiers: .command)
    }
}

// Isolated menu bar content view to prevent constant updates
struct MenuBarContentView: View {
    @Environment(\.openWindow) private var openWindow
    
    let currentState: AppState
    let audioLevels: [Float]
    let statusText: String
    let hotkeyDisplay: String
    let showInMenuBar: Bool
    let onStartRecording: () -> Void
    let onStopRecording: () -> Void
    let onQuit: () -> Void
    
    var body: some View {
        if showInMenuBar {
            ZStack {
                // Glassmorphic background
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 6)
                
                VStack(alignment: .leading, spacing: 0) {
                    // Status header
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.18))
                                .frame(width: 28, height: 28)
                            Image(systemName: "mic.circle.fill")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.blue)
                        }
                        Text(statusText)
                            .font(.body)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 8)
                    
                    // Optional: Compact waveform when recording
                    if currentState == .recording {
                        CompactWaveformView(audioLevels: audioLevels, isRecording: true)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 8)
                    }
                    
                    Divider().background(Color.white.opacity(0.15)).padding(.horizontal, 8)
                        .padding(.bottom, 2)
                    
                    // Quick Actions
                    VStack(spacing: 0) {
                        if currentState == .recording {
                            MenuBarActionButton(
                                title: "Stop Recording",
                                systemImage: "stop.circle",
                                isEnabled: true,
                                action: onStopRecording
                            )
                        } else {
                            MenuBarActionButton(
                                title: "Start Recording (\(hotkeyDisplay))",
                                systemImage: "record.circle",
                                isEnabled: currentState == .idle,
                                action: onStartRecording
                            )
                        }
                        
                        // Open Settings
                        MenuBarActionButton(
                            title: "Settings",
                            systemImage: "gearshape.fill",
                            isEnabled: true,
                            action: {
                                NSApp.activate(ignoringOtherApps: true)
                                openWindow(id: "settings")
                            }
                        )
                        MenuBarActionButton(
                            title: "Quit WolfWhisper",
                            systemImage: "power",
                            isEnabled: true,
                            action: onQuit
                        )
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
            }
            .frame(width: 240)
            .padding(6)
        } else {
            VStack {
                Text("Menu bar disabled")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Button("Enable in Settings") {
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "settings")
                }
            }
            .padding(8)
            .frame(width: 150)
        }
    }
}



// Modern action button for menu bar
struct MenuBarActionButton: View {
    let title: String
    let systemImage: String
    let isEnabled: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(isEnabled ? .blue : .gray)
                Text(title)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(isEnabled ? .primary : .gray)
                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isEnabled ? Color.blue.opacity(0.08) : Color.gray.opacity(0.05))
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!isEnabled)
        .padding(.vertical, 2)
    }
} 