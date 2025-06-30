import Foundation
import SwiftUI
import Observation

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate, Sendable {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    
    var appState: AppStateModel!
    private var hotkeyService: HotkeyService!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Set the app to be a UIElement (menu bar only, no dock icon)
        NSApplication.shared.setActivationPolicy(.accessory)

        // Initialize services and state
        appState = AppStateModel()
        hotkeyService = HotkeyService(appState: appState)
        hotkeyService.startMonitoring()
        
        // Create the status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: appState.currentState.rawValue, accessibilityDescription: "WolfWhisper")
            button.action = #selector(togglePopover(_:))
        }
        
        // Create the popover and its content view
        popover = NSPopover()
        popover.contentSize = NSSize(width: 300, height: 280)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: ContentView(appState: appState))
        
        // Listen for state changes to update the icon
        withObservationTracking {
            _ = self.appState.currentState
        } onChange: {
            DispatchQueue.main.async {
                self.updateStatusItemIcon()
            }
        }
    }

    func updateStatusItemIcon() {
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: appState.currentState.rawValue, accessibilityDescription: "WolfWhisper")
        }
    }

    @objc func togglePopover(_ sender: Any?) {
        if let button = statusItem.button {
            if popover.isShown {
                popover.performClose(sender)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            }
        }
    }
} 