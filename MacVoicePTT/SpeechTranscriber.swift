import Foundation
import Speech

enum SpeechTranscriberError: LocalizedError {
    case recognizerUnavailable
    case noRecognitionResult

    var errorDescription: String? {
        switch self {
        case .recognizerUnavailable:
            return "The macOS Speech recognizer is unavailable for the current locale."
        case .noRecognitionResult:
            return "Speech recognition completed without a transcript."
        }
    }
}

final class SpeechTranscriber {
    private var activeTask: SFSpeechRecognitionTask?

    func transcribeFile(at url: URL) async throws -> String {
        activeTask?.cancel()

        guard let recognizer = SFSpeechRecognizer(locale: Locale.current), recognizer.isAvailable else {
            throw SpeechTranscriberError.recognizerUnavailable
        }

        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false

        return try await withCheckedThrowingContinuation { continuation in
            var didResume = false

            self.activeTask = recognizer.recognitionTask(with: request) { result, error in
                if let error, !didResume {
                    didResume = true
                    self.activeTask = nil
                    continuation.resume(throwing: error)
                    return
                }

                if let result, result.isFinal, !didResume {
                    didResume = true
                    self.activeTask = nil
                    continuation.resume(returning: result.bestTranscription.formattedString)
                }
            }
        }
    }
}
