# WolfWhisper: Product Requirements Document

## 1. Vision & Core Problem
**WolfWhisper** is a personal, high-performance AI dictation utility for macOS. It is engineered for a technically proficient user who wants to leverage their own powerful hardware (Apple Silicon) and AI API keys.

The core problem it solves is the need for a powerful, private, and cost-effective voice-to-text engine without being tied to a commercial SaaS subscription model. By adopting a "bring-your-own-API-key" approach, the user gains ultimate control, transparency, and only pays for what they use. The final product will be a lightweight, system-wide menu bar utility focused on converting spoken intent into polished, well-formatted text.

---

## 2. Target Features

### 2.1 Minimum Viable Product (MVP)
The MVP focuses on delivering the core "thought-to-text" loop with personal API keys.

| Feature                      | Requirement                                                                                                                              |
| ---------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| **System-Wide Activation** | A user-configurable global hotkey to start and stop dictation. The default mode will be "Push-to-Talk" (press and hold).                   |
| **Interface** | A macOS menu bar utility (`MenuBarExtra`) that provides access to settings and visual feedback.                                        |
| **Core AI Pipeline** | The app captures audio, sends it to an STT API for transcription, and then sends the raw text to an LLM API for cleanup and formatting.     |
| **BYO-API-Key** | A settings panel where a user can securely input and save their API keys for the selected AI services (e.g., OpenAI).                      |
| **Automatic Text Insertion** | The final, polished text is automatically pasted into the active application's focused text field.                                         |
| **User Feedback** | The menu bar icon changes to indicate status (idle, recording, processing). Subtle audio cues confirm success or failure.                  |

### 2.2 Post-MVP Roadmap
| Version | Feature                     | Description                                                                                                                                       |
| ------- | --------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| **v1.1** | **Custom Vocabulary** | Allow users to define a list of custom names, acronyms, or jargon to be injected into the LLM prompt, improving accuracy for specialized work.     |
| **v1.1** | **Hands-Free Mode** | Add a toggle mode (press to start, press to stop) for dictating longer-form content.                                                              |
| **v1.2** | **Voice Command Editing** | Implement a "command mode" (e.g., triggered by "Whisper command") to allow for voice-based text manipulation like selecting and rewriting.          |
| **v2.0** | **Offline STT Models** | Integrate a local, on-device STT model like `whisper.cpp` to enhance privacy, reduce latency, and enable offline functionality.                     |

---

## 3. System Architecture & Logic

### 3.1 Architectural Flow
The system is a state-driven application that follows a clear, unidirectional data flow:

1.  **Input**: User presses the global hotkey.
2.  **State Change**: The app state moves from `idle` to `recording`.
3.  **Audio Capture**: `AVFoundation` captures microphone audio into a buffer.
4.  **Input**: User releases the hotkey.
5.  **State Change**: The app state moves to `processing`.
6.  **AI Network Calls (Sequential)**:
    * **STT API**: The audio data is sent to the **OpenAI Whisper API**.
    * **LLM API**: The raw transcript is sent with a master prompt to the **OpenAI GPT-4o-mini API**.
7.  **Text Insertion**: The final, cleaned text is pasted into the active application.
8.  **State Change**: The app state returns to `idle`.

### 3.2 The Text Enhancement Engine
The quality of the final output depends critically on the LLM prompt. The following master prompt will be used to process the raw transcript.

> You are an expert editor tasked with processing a raw, verbatim audio transcript. Your goal is to transform it into clean, well-structured, and grammatically perfect prose. Follow these instructions precisely:
>
> 1.  Correct all spelling and grammatical errors.
> 2.  Insert appropriate punctuation, including periods, commas, question marks, and capitalization at the beginning of sentences and for all proper nouns.
> 3.  Remove all filler words and speech disfluencies. This includes, but is not limited to: "um", "uh", "ah", "er", "like", "you know", "I mean", and any repeated words or stutters. The final output must not contain any of these.
> 4.  Structure the text logically. Combine short, fragmented phrases into coherent sentences. Group related sentences into paragraphs. If the user's speech pattern clearly implies a list of items, format it as a bulleted list using hyphens.
> 5.  Preserve the original meaning and intent. Do not add any new information, opinions, or commentary. Your sole function is to clean and format the provided text.
> 6.  Output only the final, cleaned text. Do not include any preambles, apologies, or explanations. Do not wrap the final output in quotation marks or code blocks.

---

## 4. Operational Model & Cost
The application operates on a direct usage cost model. Users are responsible for costs incurred on their personal API keys. This provides a significant financial advantage over fixed subscriptions for many users.

**Estimated Monthly Cost Projection (OpenAI Stack):**

| Daily Usage (Speech) | Monthly Usage (Hours) | Whisper Cost (@$0.006/min) | GPT-4o-mini Cost (Est.) | **Total Estimated Monthly Cost (USD)** |
| -------------------- | --------------------- | -------------------------- | ----------------------- | -------------------------------------- |
| Light (10 min/day)   | 5 hours               | $1.80                      | $0.45                   | **$2.25** |
| Medium (30 min/day)  | 15 hours              | $5.40                      | $1.35                   | **$6.75** |
| Heavy (60 min/day)   | 30 hours              | $10.80                     | $2.70                   | **$13.50** |