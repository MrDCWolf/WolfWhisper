import SwiftUI
import AppKit

// Custom window class that doesn't steal focus
class NonFocusingWindow: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@main
struct WolfWhisperApp: App {
    @StateObject private var appState = AppStateModel()
    @State private var settingsWindow: NSWindow?
    @State private var floatingRecordingWindow: NSWindow?
    @State private var settingsWindowDelegate: SettingsWindowDelegate?
    @State private var floatingWindowDelegate: FloatingWindowDelegate?
    
    var body: some Scene {
        WindowGroup {
            if appState.isFirstLaunch {
                OnboardingView(appState: appState)
            } else {
                ContentView(appState: appState)
            }
        }
        .windowResizability(.contentSize)
        .onChange(of: appState.showSettings) { _, newValue in
            if newValue {
                openSettingsWindow()
            } else {
                closeSettingsWindow()
            }
        }
        .onChange(of: appState.currentState) { _, newState in
            handleStateChange(newState)
        }
    }
    
    private func openSettingsWindow() {
        if settingsWindow == nil {
            let settingsView = SettingsView(appState: appState)
            let hostingController = NSHostingController(rootView: settingsView)
            
            settingsWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 700, height: 500),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            
            settingsWindow?.title = "Settings"
            settingsWindow?.contentViewController = hostingController
            settingsWindow?.center()
            settingsWindow?.setFrameAutosaveName("SettingsWindow")
            settingsWindow?.isReleasedWhenClosed = false
            
            // Handle window close
            settingsWindowDelegate = SettingsWindowDelegate(appState: appState)
            settingsWindow?.delegate = settingsWindowDelegate
        } else {
            // Using existing settings window
        }
        
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private func closeSettingsWindow() {
        settingsWindow?.close()
    }
    
    private func handleStateChange(_ newState: AppState) {
        // Show floating window for ALL recording sessions (both hotkey and button)
        if newState == .recording || newState == .transcribing {
            showFloatingRecordingWindow()
        } else if newState == .idle && floatingRecordingWindow?.isVisible == true {
            // Hide floating window after a short delay to show completion state
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self.hideFloatingRecordingWindow()
            }
        }
    }
    
    private func showFloatingRecordingWindow() {
        if floatingRecordingWindow == nil {
            let recordingView = FloatingRecordingView(appState: appState)
            let hostingController = NSHostingController(rootView: recordingView)
            
            floatingRecordingWindow = NonFocusingWindow(
                contentRect: NSRect(x: 0, y: 0, width: 300, height: 200),
                styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            
            floatingRecordingWindow?.title = "WolfWhisper Recording"
            floatingRecordingWindow?.contentViewController = hostingController
            floatingRecordingWindow?.center()
            floatingRecordingWindow?.level = .floating
            floatingRecordingWindow?.isOpaque = false
            floatingRecordingWindow?.backgroundColor = NSColor.clear
            floatingRecordingWindow?.hasShadow = true
            floatingRecordingWindow?.isReleasedWhenClosed = false
            
            // Handle window close
            floatingWindowDelegate = FloatingWindowDelegate(appState: appState)
            floatingRecordingWindow?.delegate = floatingWindowDelegate
        }
        
        floatingRecordingWindow?.orderFront(nil)
    }
    
    private func hideFloatingRecordingWindow() {
        floatingRecordingWindow?.close()
    }
}

class SettingsWindowDelegate: NSObject, NSWindowDelegate {
    let appState: AppStateModel
    
    init(appState: AppStateModel) {
        self.appState = appState
    }
    
    func windowWillClose(_ notification: Notification) {
        appState.showSettings = false
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
    }
} 