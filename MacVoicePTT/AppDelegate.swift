import AppKit
import Carbon

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let statusMenu = NSMenu()
    private let statusMenuItem = NSMenuItem(title: "Starting…", action: nil, keyEquivalent: "")
    private let hotkeyMenuItem = NSMenuItem(title: "Hotkey: Control + Option + Space", action: nil, keyEquivalent: "")
    private lazy var copyLastTranscriptMenuItem = NSMenuItem(
        title: "Copy Last Transcript",
        action: #selector(copyLastTranscript),
        keyEquivalent: ""
    )

    private lazy var requestPermissionsMenuItem = NSMenuItem(
        title: "Request Permissions",
        action: #selector(requestPermissions),
        keyEquivalent: ""
    )

    private lazy var hotkeyManager = HotkeyManager(
        keyCode: UInt32(kVK_Space),
        modifiers: UInt32(controlKey) | UInt32(optionKey)
    )

    private let permissionManager = PermissionManager()
    private let audioRecorder = AudioRecorderService()
    private let speechTranscriber = SpeechTranscriber()
    private let textInsertionService = TextInsertionService()

    private var isRecording = false
    private var isTranscribing = false
    private var lastTranscript = ""

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureStatusItem()
        configureHotkey()
        updateStatus(indicator: "PTT", detail: "Requesting permissions…")

        Task { [weak self] in
            await self?.refreshPermissions(promptForAccessibility: true)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyManager.unregister()
    }

    @objc private func requestPermissions() {
        Task { [weak self] in
            await self?.refreshPermissions(promptForAccessibility: true)
        }
    }

    @objc private func copyLastTranscript() {
        guard !lastTranscript.isEmpty else { return }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(lastTranscript, forType: .string)
        updateStatus(indicator: "PTT", detail: "Last transcript copied to clipboard.")
    }

    private func configureStatusItem() {
        if let button = statusItem.button {
            button.title = "PTT"
            button.toolTip = "Mac Voice PTT"
        }

        statusMenuItem.isEnabled = false
        hotkeyMenuItem.isEnabled = false
        copyLastTranscriptMenuItem.target = self
        copyLastTranscriptMenuItem.isEnabled = false
        requestPermissionsMenuItem.target = self

        let quitItem = NSMenuItem(
            title: "Quit",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = NSApp

        statusMenu.removeAllItems()
        statusMenu.addItem(statusMenuItem)
        statusMenu.addItem(hotkeyMenuItem)
        statusMenu.addItem(.separator())
        statusMenu.addItem(requestPermissionsMenuItem)
        statusMenu.addItem(copyLastTranscriptMenuItem)
        statusMenu.addItem(.separator())
        statusMenu.addItem(quitItem)

        statusItem.menu = statusMenu
    }

    private func configureHotkey() {
        hotkeyManager.onPress = { [weak self] in
            DispatchQueue.main.async {
                self?.handleHotkeyPress()
            }
        }

        hotkeyManager.onRelease = { [weak self] in
            DispatchQueue.main.async {
                self?.handleHotkeyRelease()
            }
        }

        do {
            try hotkeyManager.register()
        } catch {
            updateStatus(indicator: "ERR", detail: "Failed to register global hotkey: \(error.localizedDescription)")
        }
    }

    private func handleHotkeyPress() {
        guard !isRecording, !isTranscribing else { return }

        Task { [weak self] in
            guard let self else { return }

            let permissions = await self.permissionManager.requestAllPermissions(promptForAccessibility: false)
            guard permissions.microphoneAuthorized, permissions.speechAuthorized else {
                self.updateStatus(
                    indicator: "ERR",
                    detail: "Microphone and Speech permissions are required before recording."
                )
                return
            }

            do {
                try self.audioRecorder.startRecording()
                self.isRecording = true
                self.updateStatus(indicator: "REC", detail: "Recording… release Control + Option + Space to transcribe.")
            } catch {
                self.updateStatus(indicator: "ERR", detail: "Unable to start recording: \(error.localizedDescription)")
            }
        }
    }

    private func handleHotkeyRelease() {
        guard isRecording, !isTranscribing else { return }

        isRecording = false

        guard let recordingURL = audioRecorder.stopRecording() else {
            updateStatus(indicator: "ERR", detail: "Recording stopped, but no audio file was captured.")
            return
        }

        isTranscribing = true
        updateStatus(indicator: "TXT", detail: "Transcribing…")

        Task { [weak self] in
            guard let self else { return }

            defer {
                self.isTranscribing = false
                try? FileManager.default.removeItem(at: recordingURL)
            }

            do {
                let transcript = try await self.speechTranscriber.transcribeFile(at: recordingURL)
                let cleanedTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)

                guard !cleanedTranscript.isEmpty else {
                    self.updateStatus(indicator: "PTT", detail: "No speech detected. Try again.")
                    return
                }

                self.lastTranscript = cleanedTranscript
                self.copyLastTranscriptMenuItem.isEnabled = true

                switch await self.textInsertionService.insert(cleanedTranscript) {
                case .pasted:
                    self.updateStatus(indicator: "PTT", detail: "Transcript pasted into the active app.")
                case .copiedToClipboard:
                    self.updateStatus(
                        indicator: "PTT",
                        detail: "Accessibility permission missing or paste unavailable. Transcript copied to clipboard."
                    )
                }
            } catch {
                self.updateStatus(indicator: "ERR", detail: "Transcription failed: \(error.localizedDescription)")
            }
        }
    }

    private func refreshPermissions(promptForAccessibility: Bool) async {
        let permissions = await permissionManager.requestAllPermissions(promptForAccessibility: promptForAccessibility)

        if permissions.microphoneAuthorized && permissions.speechAuthorized {
            if permissions.accessibilityAuthorized {
                updateStatus(indicator: "PTT", detail: "Ready. Hold Control + Option + Space to dictate and paste.")
            } else {
                updateStatus(
                    indicator: "PTT",
                    detail: "Ready. Accessibility is not granted, so transcripts will be copied to the clipboard."
                )
            }
        } else {
            updateStatus(
                indicator: "ERR",
                detail: "Grant Microphone and Speech permissions, then use Request Permissions from the menu."
            )
        }
    }

    private func updateStatus(indicator: String, detail: String) {
        statusItem.button?.title = indicator
        statusItem.button?.toolTip = detail
        statusMenuItem.title = detail
    }
}
