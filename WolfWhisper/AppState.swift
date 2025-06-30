import Foundation
import SwiftUI

// The various states the application can be in.
enum AppState: String {
    case idle = "mic"
    case recording = "mic.fill"
    case processing = "brain"
    case error = "exclamationmark.triangle"
}

// An observable class to manage and publish the application's state.
@Observable
class AppStateModel {
    var currentState: AppState = .idle
    var statusText: String = "Ready"

    @MainActor
    func updateState(to newState: AppState, message: String? = nil) {
        self.currentState = newState
        
        switch newState {
        case .idle:
            self.statusText = message ?? "Ready"
        case .recording:
            self.statusText = message ?? "Recording..."
        case .processing:
            self.statusText = message ?? "Processing..."
        case .error:
            self.statusText = message ?? "An error occurred."
        }
    }
} 