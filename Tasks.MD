# WolfWhisper: Development Tasks

This document breaks down the development of WolfWhisper into a series of phased, actionable tasks.

---

## Phase 1: Application Shell & UI
*Objective: Create the basic, non-functional macOS menu bar application.*

- [ ] **Project Setup**: Create a new macOS App project in Xcode/Cursor using Swift and SwiftUI.
- [ ] **Implement Menu Bar UI**: Replace the default `WindowGroup` with a `MenuBarExtra` scene in `App.swift`.
- [ ] **Hide Dock Icon**: Add the `Application is agent (UIElement)` key to `Info.plist` and set its value to `YES` to run as a background utility.
- [ ] **Build Settings View**: Create `SettingsView.swift` with placeholders for API key input, hotkey configuration, and a "Quit" button.
- [ ] **Implement Secure Storage**: Create a `KeychainService` wrapper class to securely store and retrieve the API key using the macOS Keychain. Do not use `UserDefaults`.

---

## Phase 2: Audio Capture Pipeline
*Objective: Implement the logic for recording audio from the microphone.*

- [ ] **Request Microphone Permission**: Add the `Privacy - Microphone Usage Description` key to `Info.plist` with a clear explanation.
- [ ] **Create AudioService**: Implement a singleton `AudioService` class to encapsulate all `AVFoundation` logic.
- [ ] **Setup AVAudioEngine**: Initialize an `AVAudioEngine` instance within the `AudioService`.
- [ ] **Implement `startRecording()`**:
    - [ ] Create a tap on the engine's `inputNode` using `installTap(...)`.
    - [ ] In the tap's block, write the incoming `AVAudioPCMBuffer` to a temporary audio file.
    - [ ] Start the audio engine.
- [ ] **Implement `stopRecording()`**:
    - [ ] Stop the audio engine and remove the tap.
    - [ ] Close the audio file and return its `URL`.

---

## Phase 3: System-Wide Control
*Objective: Register a global hotkey and manage the application's state.*

- [ ] **Implement Global Hotkey Monitor**: Create a `HotkeyService` class that uses `CGEvent.tapCreate` to monitor system-wide `keyDown` and `keyUp` events.
- [ ] **Define State Machine**: Create a Swift `enum AppState { case idle, recording, processing, error }` and use an `@Observable` class to manage the current state.
- [ ] **Connect Services**:
    - [ ] On hotkey `keyDown` event: transition `AppState` to `.recording` and call `AudioService.startRecording()`.
    - [ ] On hotkey `keyUp` event: call `AudioService.stopRecording()`, get the audio file URL, and transition `AppState` to `.processing`.

---

## Phase 4: AI Core Integration
*Objective: Connect to the OpenAI backend to perform transcription and cleanup.*

- [ ] **Build NetworkService**: Create a singleton `NetworkService` class using `URLSession` and modern `async/await`.
- [ ] **Implement Whisper API Call**:
    - [ ] Create an `async throws` function `transcribe(audioURL: URL)`.
    - [ ] Construct a `multipart/form-data` `URLRequest` to the OpenAI `/v1/audio/transcriptions` endpoint.
    - [ ] Include the `whisper-1` model and API key `Authorization` header.
    - [ ] Execute the request and parse the JSON response to return the transcript `String`.
- [ ] **Implement LLM API Call**:
    - [ ] Create an `async throws` function `cleanup(transcript: String)`.
    - [ ] Construct a JSON `URLRequest` to the OpenAI `/v1/chat/completions` endpoint.
    - [ ] Include the `gpt-4o-mini` model, the master prompt, the user's transcript, and the API key header.
    - [ ] Execute the request and parse the JSON to return the final cleaned text `String`.
- [ ] **Chain API Calls**: In the main controller, `await` the `transcribe` call, then use its result to `await` the `cleanup` call.

---

## Phase 5: Text Injection & User Feedback
*Objective: Deliver the final text to the user and provide status feedback.*

- [ ] **Implement InsertionService**: Create an `InsertionService` class.
- [ ] **Implement Paste via Keystroke**:
    - [ ] Write a `paste(text: String)` method.
    - [ ] Clear the system `NSPasteboard`.
    - [ ] Write the final text to the pasteboard.
    - [ ] Use `CGEvent` to programmatically generate `Cmd+V` key events.
- [ ] **Add Visual Feedback**: Bind the `MenuBarExtra`'s `systemImage` to the `AppState` to show different icons for `idle`, `recording`, and `processing`.
- [ ] **Add Audio Feedback**: Use `AVAudioPlayer` to play subtle sound effects for recording start, success, and error events.

---

## Phase 6: Distribution & Deployment
*Objective: Prepare the application for use on any modern Mac.*

- [ ] **Obtain Developer Certificate**: Ensure a "Developer ID Application" certificate is present in your Keychain via an Apple Developer Program membership.
- [ ] **Enable Hardened Runtime**: In Xcode's "Signing & Capabilities", add the "Hardened Runtime" capability.
- [ ] **Archive Application**: Use Xcode's `Product > Archive` command.
- [ ] **Notarize Application**: Export the archive for "Direct Distribution" and submit the `.app` file using the `notarytool` command-line utility.
- [ ] **Staple Notarization Ticket**: Once notarization succeeds, run the `xcrun stapler staple` command on the `.app` bundle.
- [ ] **Package for Distribution**: Compress the final, signed, and stapled `.app` into a `.zip` file.