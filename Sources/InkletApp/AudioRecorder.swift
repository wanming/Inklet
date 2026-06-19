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

    private var captureSession: AVCaptureSession?
    private var fileOutput: AVCaptureAudioFileOutput?
    private var recordingDelegate: AudioRecordingDelegate?
    private var recordingURL: URL?

    func start(microphoneDeviceID: String?) async throws {
        guard await requestMicrophoneAccess() else {
            throw AudioRecorderError.microphonePermissionDenied
        }
        guard let device = audioDevice(matching: microphoneDeviceID) else {
            throw AudioRecorderError.noAudioInputDevice
        }

        await cancel()
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("inklet-voice-\(UUID().uuidString)")
            .appendingPathExtension("m4a")

        let captureSession = AVCaptureSession()
        let input = try AVCaptureDeviceInput(device: device)
        let fileOutput = AVCaptureAudioFileOutput()
        guard captureSession.canAddInput(input), captureSession.canAddOutput(fileOutput) else {
            throw AudioRecorderError.recordingUnavailable
        }

        captureSession.beginConfiguration()
        captureSession.addInput(input)
        captureSession.addOutput(fileOutput)
        captureSession.commitConfiguration()

        let recordingDelegate = AudioRecordingDelegate()
        self.captureSession = captureSession
        self.fileOutput = fileOutput
        self.recordingDelegate = recordingDelegate
        recordingURL = url

        captureSession.startRunning()
        fileOutput.startRecording(to: url, outputFileType: .m4a, recordingDelegate: recordingDelegate)
        guard captureSession.isRunning, fileOutput.isRecording else {
            stopCaptureSession()
            recordingURL = nil
            try? FileManager.default.removeItem(at: url)
            throw AudioRecorderError.recordingUnavailable
        }
    }

    func stop() async throws -> URL {
        guard let fileOutput, let recordingDelegate, let recordingURL else {
            throw AudioRecorderError.recordingUnavailable
        }

        fileOutput.stopRecording()
        do {
            try await recordingDelegate.waitUntilFinished()
        } catch {
            stopCaptureSession()
            self.recordingURL = nil
            try? FileManager.default.removeItem(at: recordingURL)
            throw AudioRecorderError.recordingUnavailable
        }

        stopCaptureSession()
        self.recordingURL = nil
        return recordingURL
    }

    func cancel() async {
        let fileOutput = fileOutput
        let recordingDelegate = recordingDelegate
        let recordingURL = recordingURL
        if fileOutput?.isRecording == true {
            fileOutput?.stopRecording()
            try? await recordingDelegate?.waitUntilFinished()
        }
        stopCaptureSession()
        if let recordingURL {
            try? FileManager.default.removeItem(at: recordingURL)
        }
        self.recordingURL = nil
    }

    private func stopCaptureSession() {
        captureSession?.stopRunning()
        captureSession = nil
        fileOutput = nil
        recordingDelegate = nil
    }

    private func audioDevice(matching deviceID: String?) -> AVCaptureDevice? {
        if let deviceID,
           let selectedDevice = MicrophoneDeviceCatalog.availableAudioDevices().first(where: { $0.uniqueID == deviceID }) {
            return selectedDevice
        }

        return AVCaptureDevice.default(for: .audio)
    }

    private func requestMicrophoneAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .notDetermined:
            return await Self.requestMicrophoneAccessFromSystem()
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    private nonisolated static func requestMicrophoneAccessFromSystem() async -> Bool {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                continuation.resume(returning: granted)
            }
        }
    }
}

private final class AudioRecordingDelegate: NSObject, AVCaptureFileOutputRecordingDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, Error>?
    private var result: Result<Void, Error>?

    func waitUntilFinished() async throws {
        try await withCheckedThrowingContinuation { continuation in
            lock.lock()
            if let result {
                lock.unlock()
                continuation.resume(with: result)
            } else {
                self.continuation = continuation
                lock.unlock()
            }
        }
    }

    func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        let result: Result<Void, Error> = error.map(Result.failure) ?? .success(())

        lock.lock()
        if let continuation {
            self.continuation = nil
            lock.unlock()
            continuation.resume(with: result)
        } else {
            self.result = result
            lock.unlock()
        }
    }
}
