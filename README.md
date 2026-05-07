# Mac Voice PTT Swift

Native macOS Apple Silicon push-to-talk dictation MVP written in Swift with AppKit, AVFoundation, Speech, and Carbon.

## What this MVP does

- Runs as a menu bar utility (`LSUIElement`) instead of a normal dock-first app
- Uses a global push-to-talk hotkey: **Control + Option + Space**
- Records microphone audio while the hotkey is held
- Transcribes speech with Apple's native `Speech` framework
- Tries to paste the transcript into the currently active app
- Falls back to copying the transcript to the clipboard when Accessibility permission is not granted

## Requirements

- Apple Silicon Mac (M1/M2/M3 or newer)
- macOS 13.0+
- Xcode 15+
- A signed local build in Xcode so macOS permission prompts work normally

## Build and run

1. Open `MacVoicePTT.xcodeproj` in Xcode.
2. Select the `MacVoicePTT` target.
3. In **Signing & Capabilities**, choose your personal or team signing identity if Xcode asks for one.
4. Build and run the app on an Apple Silicon Mac.
5. A `PTT` menu bar item should appear after launch.

## Required permissions

The app is designed to work best when these permissions are granted:

- **Microphone**: required to record dictation audio
- **Speech Recognition**: required to transcribe spoken audio
- **Accessibility**: required for automatic paste into the active application

If Accessibility permission is missing, the app still works, but it will **copy the transcript to the clipboard instead of pasting it automatically**.

## Usage

1. Launch the app from Xcode or a built app bundle.
2. Grant Microphone and Speech Recognition permission when prompted.
3. Grant Accessibility permission in **System Settings → Privacy & Security → Accessibility** for automatic paste support.
4. Hold **Control + Option + Space** to record.
5. Release the hotkey to stop recording and start transcription.
6. The transcript is pasted into the currently focused app when possible.

## How it works

- `Carbon` registers a reliable global hotkey for press and release events.
- `AVAudioRecorder` records a temporary AAC file while the hotkey is held.
- `SFSpeechRecognizer` transcribes the recorded audio after release.
- `NSPasteboard` stores the transcript, and the app sends a synthetic `⌘V` paste only when Accessibility access is available.

## Known limitations

- The MVP uses a fixed hotkey and does not yet expose a preferences UI.
- Apple Speech may use Apple's speech service when on-device recognition is unavailable.
- Some apps may ignore synthetic paste events even when Accessibility permission is granted; in that case the transcript still remains on the clipboard.
- The MVP transcribes after recording stops instead of streaming partial live text.

## Project structure

- `MacVoicePTT.xcodeproj` — Xcode project
- `MacVoicePTT/Main.swift` — app entry point
- `MacVoicePTT/AppDelegate.swift` — menu bar UI and app flow
- `MacVoicePTT/HotkeyManager.swift` — global push-to-talk hotkey
- `MacVoicePTT/AudioRecorderService.swift` — microphone recording
- `MacVoicePTT/SpeechTranscriber.swift` — speech-to-text
- `MacVoicePTT/TextInsertionService.swift` — paste or clipboard fallback
- `MacVoicePTT/PermissionManager.swift` — permission checks and prompts
