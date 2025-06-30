import SwiftUI
import AppKit

@main
struct WolfWhisperApp: App {
    // Use the App Delegate adapter to hook into the application lifecycle
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // This is a "dummy" scene since the AppDelegate now controls the UI.
        Settings {
            // This is required for the app lifecycle but is not visible.
        }
    }
} 