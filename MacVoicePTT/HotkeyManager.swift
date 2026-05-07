import Carbon
import Foundation

enum HotkeyError: LocalizedError {
    case registerFailed(OSStatus)
    case handlerInstallFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .registerFailed(let status):
            return "RegisterEventHotKey failed with status \(status)."
        case .handlerInstallFailed(let status):
            return "InstallEventHandler failed with status \(status)."
        }
    }
}

final class HotkeyManager {
    var onPress: (() -> Void)?
    var onRelease: (() -> Void)?

    private let keyCode: UInt32
    private let modifiers: UInt32

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    init(keyCode: UInt32, modifiers: UInt32) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    deinit {
        unregister()
    }

    func register() throws {
        unregister()

        var eventTypes = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))
        ]

        let installStatus = eventTypes.withUnsafeMutableBufferPointer { buffer in
            InstallEventHandler(
                GetApplicationEventTarget(),
                { _, eventRef, userData in
                    guard let eventRef, let userData else { return noErr }

                    let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                    let eventKind = GetEventKind(eventRef)

                    if eventKind == UInt32(kEventHotKeyPressed) {
                        manager.onPress?()
                    } else if eventKind == UInt32(kEventHotKeyReleased) {
                        manager.onRelease?()
                    }

                    return noErr
                },
                UInt32(buffer.count),
                buffer.baseAddress,
                Unmanaged.passUnretained(self).toOpaque(),
                &handlerRef
            )
        }

        guard installStatus == noErr else {
            throw HotkeyError.handlerInstallFailed(installStatus)
        }

        var hotKeyID = EventHotKeyID(signature: OSType(0x50545431), id: 1)
        let registerStatus = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        guard registerStatus == noErr else {
            unregister()
            throw HotkeyError.registerFailed(registerStatus)
        }
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }

        if let handlerRef {
            RemoveEventHandler(handlerRef)
            self.handlerRef = nil
        }
    }
}
