# WolfWhisper: Technology Stack

This document outlines the specific tooling, frameworks, and technologies required to build the WolfWhisper macOS application.

---

## Core Application
- **Programming Language**: **Swift**
- **Application Framework**: **SwiftUI**
- **IDE**: **Cursor** / **Xcode** 15+

---

## macOS Integration APIs
- **User Interface**:
    - **`MenuBarExtra`**: The modern SwiftUI API for creating menu bar applications.
    - **`Info.plist`**: Configuration file used to set `LSUIElement` (`Application is agent`) to `true`, hiding the app from the Dock.

- **Audio System**:
    - **`AVFoundation`**: Apple's high-level framework for audio-visual media.
    - **`AVAudioEngine`**: The specific class used to manage audio flow, access the microphone input node, and install a "tap" for real-time audio capture.

- **System-Wide Controls**:
    - **`Core Graphics`**: Low-level framework used for system interaction.
    - **`CGEvent.tapCreate`**: The specific C-based API used to create an event tap for monitoring global keyboard events (the hotkey).
    - **`NSPasteboard`**: AppKit class for interacting with the system clipboard to prepare for pasting.

- **Secure Data Storage**:
    - **`Security` Framework**: The underlying framework for interacting with the macOS **Keychain**. Used for secure storage of the user's API keys.

- **Accessibility (Post-MVP Fallback)**:
    - **`AXUIElement`**: The Accessibility API, to be used as a fallback for direct text insertion in non-standard applications.

---

## AI Backend & Networking
- **Speech-to-Text (STT)**:
    - **Service**: **OpenAI Whisper API**
    - **Model**: `whisper-1`

- **Text Generation & Cleanup**:
    - **Service**: **OpenAI Chat Completions API**
    - **Model**: `gpt-4o-mini`

- **Networking Layer**:
    - **`URLSession`**: Native Swift framework for handling HTTP requests.
    - **`async/await`**: Modern Swift concurrency features for managing asynchronous network calls.

---

## Deployment & Distribution
- **Prerequisite**: **Apple Developer Program Membership**
- **Code Signing Certificate**: **Developer ID Application**
- **Command-Line Tooling**:
    - **`notarytool`**: For submitting the application to Apple's notarization service.
    - **`stapler`**: For attaching the notarization ticket to the application bundle.