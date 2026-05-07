import AppKit
import ApplicationServices
import Carbon
import Foundation

enum TextInsertionOutcome {
    case pasted
    case copiedToClipboard
}

final class TextInsertionService {
    private let pasteboardPropagationDelay: TimeInterval = 0.12

    func insert(_ text: String) -> TextInsertionOutcome {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)

        guard AXIsProcessTrusted() else {
            return .copiedToClipboard
        }

        let source = CGEventSource(stateID: .combinedSessionState)
        let commandVDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true)
        let commandVUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false)

        commandVDown?.flags = .maskCommand
        commandVUp?.flags = .maskCommand

        // Give the pasteboard a brief moment to publish the new text before sending Command-V.
        Thread.sleep(forTimeInterval: pasteboardPropagationDelay)
        commandVDown?.post(tap: .cghidEventTap)
        commandVUp?.post(tap: .cghidEventTap)

        return .pasted
    }
}
