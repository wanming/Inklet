import AVFoundation
import Foundation

@MainActor
final class AudioRecorder {
    enum AudioRecorderError: Error, LocalizedError {
        case microphonePermissionDenied
        case noAudioInputDevice
        case recordingUnavailable

        var errorDescription: String? {
            switch self {
            case .microphonePermissionDenied:
                L10n.text("voice.error.microphonePermission")
            case .noAudioInputDevice:
                L10n.text("voice.error.noAudioInputDevice")
            case .recordingUnavailable:
                L10n.text("voice.error.recordingUnavailable")
            }
        }
    }

    private var recorder: AVAudioRecorder?
    private var recordingURL: URL?

    func start() async throws {
        guard await requestMicrophoneAccess() else {
            throw AudioRecorderError.microphonePermissionDenied
        }
        guard AVCaptureDevice.default(for: .audio) != nil else {
            throw AudioRecorderError.noAudioInputDevice
        }

        await cancel()
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("inklet-voice-\(UUID().uuidString)")
            .appendingPathExtension("m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.isMeteringEnabled = false
        self.recorder = recorder
        recordingURL = url
        recorder.prepareToRecord()
        guard recorder.record() else {
            self.recorder = nil
            recordingURL = nil
            throw AudioRecorderError.recordingUnavailable
        }
    }

    func stop() async throws -> URL {
        guard let recorder, let recordingURL else {
            throw AudioRecorderError.recordingUnavailable
        }

        recorder.stop()
        self.recordingURL = nil
        return recordingURL
    }

    func cancel() async {
        recorder?.stop()
        recorder = nil
        if let recordingURL {
            try? FileManager.default.removeItem(at: recordingURL)
        }
        recordingURL = nil
    }

    private func requestMicrophoneAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    continuation.resume(returning: granted)
                }
            }
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }
}
