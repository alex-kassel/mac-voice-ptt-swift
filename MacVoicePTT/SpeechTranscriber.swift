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
    private let recognitionTimeout: TimeInterval = 30
    private var activeTask: SFSpeechRecognitionTask?

    func transcribeFile(at url: URL) async throws -> String {
        activeTask?.cancel()

        guard let recognizer = SFSpeechRecognizer(locale: Locale.current), recognizer.isAvailable else {
            throw SpeechTranscriberError.recognizerUnavailable
        }

        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false

        return try await withCheckedThrowingContinuation { continuation in
            let lock = NSLock()
            var didResume = false
            var timeoutWorkItem: DispatchWorkItem?

            func resumeOnce(with result: Result<String, Error>) {
                lock.lock()
                defer { lock.unlock() }

                guard !didResume else { return }
                didResume = true
                self.activeTask = nil
                timeoutWorkItem?.cancel()

                switch result {
                case .success(let transcript):
                    continuation.resume(returning: transcript)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            self.activeTask = recognizer.recognitionTask(with: request) { result, error in
                if let error {
                    resumeOnce(with: .failure(error))
                    return
                }

                if let result, result.isFinal {
                    resumeOnce(with: .success(result.bestTranscription.formattedString))
                }
            }

            let workItem = DispatchWorkItem {
                self.activeTask?.cancel()
                resumeOnce(with: .failure(SpeechTranscriberError.noRecognitionResult))
            }
            timeoutWorkItem = workItem
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + self.recognitionTimeout, execute: workItem)
        }
    }
}
