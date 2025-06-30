import Foundation
import SwiftUI

// The various states the application can be in.
enum AppState {
    case idle
    case recording
    case transcribing
}

// An observable class to manage and publish the application's state.
@MainActor
class AppStateModel: ObservableObject {
    @Published var currentState: AppState = .idle
    @Published var statusText: String = "Ready to record"

    func updateState(to newState: AppState, message: String? = nil) {
        currentState = newState
        
        if let message = message {
            statusText = message
        } else {
            switch newState {
            case .idle:
                statusText = "Ready to record"
            case .recording:
                statusText = "Recording... Click to stop"
            case .transcribing:
                statusText = "Transcribing audio..."
            }
        }
    }
} 