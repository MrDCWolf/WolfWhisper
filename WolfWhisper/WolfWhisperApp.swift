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

@main
struct WolfWhisperApp: App {
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
        
        // Menu Bar Extra - Fixed to avoid publishing loop by removing binding
        MenuBarExtra("WolfWhisper", systemImage: "pawprint.circle.fill") {
            MenuBarView(appState: appState)
        }
        .menuBarExtraStyle(.window)
    }
    
    private func handleStateChange(_ newState: AppState) {
        // Show floating window only when starting recording
        if newState == .recording {
            showFloatingRecordingWindow()
        } else if newState == .transcribing {
            // Window should already be visible, just ensure it stays open
            // No need to call showFloatingRecordingWindow() again
        } else if newState == .idle && floatingRecordingWindow?.isVisible == true {
            // Hide floating window after a short delay to show completion state
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self.hideFloatingRecordingWindow()
            }
        }
    }
    
    private func showFloatingRecordingWindow() {
        // Always clean up existing window first
        if floatingRecordingWindow != nil {
            cleanupFloatingWindow()
        }
        
        // Create fresh window every time
        let recordingView = FloatingRecordingView(appState: appState)
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
        // Remove notification observer
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
            notificationObserver = nil
        }
        
        // Close window if it exists
        floatingRecordingWindow?.close()
        
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
            print("DEBUG: Settings menu item clicked")
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: "settings")
        }
        .keyboardShortcut(",", modifiers: .command)
    }
}

struct MenuBarView: View {
    @ObservedObject var appState: AppStateModel
    @Environment(\.openWindow) private var openWindow
    
    var body: some View {
        if appState.settings.showInMenuBar {
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
                        Text(appState.statusText)
                            .font(.body)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 8)
                    
                    // Optional: Compact waveform when recording
                    if appState.currentState == .recording {
                        CompactWaveformView(audioLevels: appState.audioLevels, isRecording: true)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 8)
                    }
                    
                    Divider().background(Color.white.opacity(0.15)).padding(.horizontal, 8)
                        .padding(.bottom, 2)
                    
                    // Quick Actions
                    VStack(spacing: 0) {
                        if appState.currentState == .recording {
                            MenuBarActionButton(
                                title: "Stop Recording",
                                systemImage: "stop.circle",
                                isEnabled: true,
                                action: {
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
                                }
                            )
                        } else {
                            MenuBarActionButton(
                                title: "Start Recording (\(appState.settings.hotkeyDisplay))",
                                systemImage: "record.circle",
                                isEnabled: appState.currentState == .idle,
                                action: {
                                    Task { 
                                        await appState.startRecordingFromMenuBar() 
                                    }
                                }
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
                            action: { NSApplication.shared.terminate(nil) }
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