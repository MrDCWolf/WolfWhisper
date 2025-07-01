import SwiftUI
import AppKit

// Custom panel class for chrome-less, non-movable floating window
class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    
    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: [.nonactivatingPanel, .fullSizeContentView], backing: backingStoreType, defer: flag)
        
        // Configure panel properties
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .stationary]
        self.isOpaque = false
        self.backgroundColor = NSColor.clear
        self.hasShadow = true
        self.isMovable = false
        
        // Remove from Dock and App Switcher
        self.hidesOnDeactivate = false
        self.worksWhenModal = true
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
        
        // Settings window as a separate scene
        WindowGroup("Settings", id: "settings") {
            SettingsView(appState: appState)
                .frame(minWidth: 700, minHeight: 500)
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        .handlesExternalEvents(matching: Set(arrayLiteral: "settings"))
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
            
            // Create chrome-less floating panel
            floatingRecordingWindow = FloatingPanel(
                contentRect: NSRect(x: 0, y: 0, width: 280, height: 280),
                styleMask: [],
                backing: .buffered,
                defer: false
            )
            
            floatingRecordingWindow?.contentViewController = hostingController
            floatingRecordingWindow?.center()
            floatingRecordingWindow?.isReleasedWhenClosed = false
            
            // Handle window close
            floatingWindowDelegate = FloatingWindowDelegate(appState: appState)
            floatingRecordingWindow?.delegate = floatingWindowDelegate
            
            // Initial scale for appearance animation
            floatingRecordingWindow?.setFrame(
                floatingRecordingWindow?.frame.applying(
                    CGAffineTransform(scaleX: 0.9, y: 0.9)
                ) ?? NSRect.zero,
                display: false
            )
            floatingRecordingWindow?.alphaValue = 0.0
        }
        
        // Animate appearance
        floatingRecordingWindow?.orderFront(nil)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            
            floatingRecordingWindow?.animator().alphaValue = 1.0
            floatingRecordingWindow?.animator().setFrame(
                NSRect(x: floatingRecordingWindow?.frame.origin.x ?? 0,
                       y: floatingRecordingWindow?.frame.origin.y ?? 0,
                       width: 280,
                       height: 280),
                display: true
            )
        }
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
            // Close window after animation completes
            window.close()
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
    }
}

struct SettingsMenuButton: View {
    @Environment(\.openWindow) private var openWindow
    
    var body: some View {
        Button("Settings...") {
            print("DEBUG: Settings menu item clicked")
            openWindow(id: "settings")
        }
        .keyboardShortcut(",", modifiers: .command)
    }
} 