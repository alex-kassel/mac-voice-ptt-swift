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

    func insert(_ text: String) async -> TextInsertionOutcome {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)

        guard AXIsProcessTrusted() else {
            return .copiedToClipboard
        }

        // Give the pasteboard a brief moment to publish the new text before sending Command-V.
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.asyncAfter(deadline: .now() + pasteboardPropagationDelay) {
                let source = CGEventSource(stateID: .combinedSessionState)
                let commandVDown = CGEvent(
                    keyboardEventSource: source,
                    virtualKey: CGKeyCode(kVK_ANSI_V),
                    keyDown: true
                )
                let commandVUp = CGEvent(
                    keyboardEventSource: source,
                    virtualKey: CGKeyCode(kVK_ANSI_V),
                    keyDown: false
                )

                guard let commandVDown, let commandVUp else {
                    continuation.resume(returning: .copiedToClipboard)
                    return
                }

                commandVDown.flags = .maskCommand
                commandVUp.flags = .maskCommand
                commandVDown.post(tap: .cghidEventTap)
                commandVUp.post(tap: .cghidEventTap)
                continuation.resume(returning: .pasted)
            }
        }
    }
}
