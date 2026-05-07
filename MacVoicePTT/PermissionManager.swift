import AVFoundation
import ApplicationServices
import Foundation
import Speech

struct PermissionSnapshot {
    let microphoneAuthorized: Bool
    let speechAuthorized: Bool
    let accessibilityAuthorized: Bool
}

final class PermissionManager {
    func requestAllPermissions(promptForAccessibility: Bool) async -> PermissionSnapshot {
        let microphoneAuthorized = await requestMicrophonePermissionIfNeeded()
        let speechAuthorized = await requestSpeechPermissionIfNeeded()
        let accessibilityAuthorized = requestAccessibilityPermissionIfNeeded(prompt: promptForAccessibility)

        return PermissionSnapshot(
            microphoneAuthorized: microphoneAuthorized,
            speechAuthorized: speechAuthorized,
            accessibilityAuthorized: accessibilityAuthorized
        )
    }

    private func requestMicrophonePermissionIfNeeded() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    continuation.resume(returning: granted)
                }
            }
        default:
            return false
        }
    }

    private func requestSpeechPermissionIfNeeded() async -> Bool {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume(returning: status == .authorized)
                }
            }
        default:
            return false
        }
    }

    private func requestAccessibilityPermissionIfNeeded(prompt: Bool) -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}
