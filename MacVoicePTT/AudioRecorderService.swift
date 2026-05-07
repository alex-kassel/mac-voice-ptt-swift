import AVFoundation
import Foundation

enum AudioRecorderError: LocalizedError {
    case startFailed

    var errorDescription: String? {
        switch self {
        case .startFailed:
            return "AVAudioRecorder did not start successfully."
        }
    }
}

final class AudioRecorderService: NSObject {
    private var recorder: AVAudioRecorder?
    private var currentRecordingURL: URL?

    func startRecording() throws {
        let temporaryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        let recorder = try AVAudioRecorder(url: temporaryURL, settings: settings)
        recorder.prepareToRecord()

        guard recorder.record() else {
            throw AudioRecorderError.startFailed
        }

        self.recorder = recorder
        currentRecordingURL = temporaryURL
    }

    func stopRecording() -> URL? {
        recorder?.stop()
        recorder = nil
        defer { currentRecordingURL = nil }
        return currentRecordingURL
    }
}
