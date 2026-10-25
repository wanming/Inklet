import AVFoundation
import Combine
import Foundation
import InkletCore

/// The dictation model is two files, the speech model and its audio encoder, downloaded together.
extension BuiltInModelDownloads {
    func isInstalled(_ model: BuiltInDictationModel) -> Bool {
        model.files.allSatisfy { isInstalled($0) }
    }

    func isDownloading(_ model: BuiltInDictationModel) -> Bool {
        model.files.contains { isDownloading($0) }
    }

    /// Pass `states` from a `$states` subscriber, which runs before the new value is stored.
    func state(
        of model: BuiltInDictationModel,
        in states: [String: BuiltInModelDownloadState]? = nil
    ) -> BuiltInModelDownloadState {
        let states = states ?? self.states
        return Self.combinedState(model.files.map { file in
            // `states` starts out with the writing models only.
            (sizeBytes: file.sizeBytes, state: states[file.id] ?? (isInstalled(file) ? .ready : .notDownloaded))
        })
    }

    func download(_ model: BuiltInDictationModel) {
        for file in model.files where !isInstalled(file) {
            download(file)
        }
    }

    func cancel(_ model: BuiltInDictationModel) {
        for file in model.files {
            cancel(file)
        }
    }

    func delete(_ model: BuiltInDictationModel) throws {
        for file in model.files {
            try delete(file)
        }
    }

    /// One state for files that download side by side: progress is weighted by size, and a failure
    /// shows once nothing is still downloading.
    static func combinedState(_ parts: [(sizeBytes: Int64, state: BuiltInModelDownloadState)]) -> BuiltInModelDownloadState {
        let isActive = parts.contains { part in
            switch part.state {
            case .downloading, .verifying: true
            case .notDownloaded, .ready, .failed: false
            }
        }
        if isActive {
            let totalBytes = parts.reduce(0) { $0 + $1.sizeBytes }
            let doneBytes = parts.reduce(0.0) { done, part in
                switch part.state {
                case .downloading(let fraction): done + fraction * Double(part.sizeBytes)
                case .verifying, .ready: done + Double(part.sizeBytes)
                case .notDownloaded, .failed: done
                }
            }
            let fraction = totalBytes > 0 ? doneBytes / Double(totalBytes) : 0
            let isVerifying = parts.allSatisfy { part in
                switch part.state {
                case .verifying, .ready: true
                case .downloading, .notDownloaded, .failed: false
                }
            }
            return isVerifying ? .verifying : .downloading(fraction: min(fraction, 1))
        }
        if let failure = parts.first(where: { if case .failed = $0.state { true } else { false } }) {
            return failure.state
        }
        return parts.allSatisfy { $0.state == .ready } ? .ready : .notDownloaded
    }
}

extension BuiltInDictationModel {
    var localizedDownloadSize: String {
        L10n.format("settings.localModel.size", Double(sizeBytes) / 1_000_000_000)
    }
}

extension VoiceInputConfig.Engine {
    var localizedName: String {
        switch self {
        case .builtIn:
            L10n.text("settings.dictationEngine.builtIn")
        case .openAI:
            L10n.text("settings.dictationEngine.openAI")
        }
    }
}

extension VoiceInputConfig {
    /// Dictation runs on the built-in engine with this config.
    var usesBuiltInEngine: Bool {
        resolvedEngine(isBuiltInEngineAvailable: BuiltInModelServer.isEngineAvailable) == .builtIn
    }
}

enum BuiltInDictationScript {
    /// Chinese dictation is written in Traditional characters when Inklet is in Traditional
    /// Chinese, or when the first Chinese in the system's preferred languages is Traditional.
    static func writesTraditionalChinese(
        interfaceLanguage: InterfaceLanguage = L10n.resolvedLanguage,
        preferredLanguages: [String] = Locale.preferredLanguages
    ) -> Bool {
        if interfaceLanguage == .traditionalChinese {
            return true
        }
        let chinese = preferredLanguages.filter { $0.lowercased().hasPrefix("zh") }
        return !chinese.isEmpty && L10n.resolveLanguage(preferredLanguages: chinese) == .traditionalChinese
    }
}

/// Keeps the dictation model ready to listen. On Macs with 16 GB of memory or more it stays loaded
/// while dictation is on. On smaller Macs it starts when the writing popover opens, the only place
/// dictation works, and the server unloads it after a few idle minutes.
@MainActor
final class BuiltInDictationResidency {
    static let shared = BuiltInDictationResidency()

    private let server: BuiltInModelServer
    private let downloads: BuiltInModelDownloads
    private let configStore: UserDefaultsConfigStore
    private let model: BuiltInDictationModel
    private var configObserver: NSObjectProtocol?
    private var downloadsCancellable: AnyCancellable?
    private var isResident = false

    init(
        server: BuiltInModelServer = .dictation,
        downloads: BuiltInModelDownloads = .shared,
        configStore: UserDefaultsConfigStore = UserDefaultsConfigStore(),
        model: BuiltInDictationModel = .recommended
    ) {
        self.server = server
        self.downloads = downloads
        self.configStore = configStore
        self.model = model
    }

    static func shouldLoad(voiceInput: VoiceInputConfig, isBuiltInEngineAvailable: Bool, isModelInstalled: Bool) -> Bool {
        voiceInput.isEnabled
            && voiceInput.resolvedEngine(isBuiltInEngineAvailable: isBuiltInEngineAvailable) == .builtIn
            && isModelInstalled
    }

    func start() {
        guard configObserver == nil else { return }
        configObserver = NotificationCenter.default.addObserver(
            forName: .appConfigDidSave,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
        // Installed files are read from disk, which is already up to date when `states` changes.
        downloadsCancellable = downloads.$states
            .dropFirst()
            .sink { [weak self] _ in
                self?.refresh()
            }
        refresh()
    }

    /// The popover is where dictation happens, so load the model as it opens.
    func popoverWillOpen(voiceInput: VoiceInputConfig) {
        guard shouldLoad(voiceInput) else { return }
        warmUp()
    }

    func terminateImmediately() {
        server.terminateImmediately()
    }

    private func refresh() {
        let voiceInput = ((try? configStore.load()) ?? AppConfig.defaultConfig()).voiceInput
        guard shouldLoad(voiceInput) else {
            if isResident || !downloads.isInstalled(model) {
                isResident = false
                let server = server
                Task { await server.stop() }
            }
            return
        }
        if server.keepsModelLoaded, !isResident {
            isResident = true
            warmUp()
        }
    }

    private func shouldLoad(_ voiceInput: VoiceInputConfig) -> Bool {
        Self.shouldLoad(
            voiceInput: voiceInput,
            isBuiltInEngineAvailable: BuiltInModelServer.isEngineAvailable,
            isModelInstalled: downloads.isInstalled(model)
        )
    }

    private func warmUp() {
        let server = server
        let model = model
        Task.detached(priority: .utility) {
            _ = try? await server.connection(
                for: model.weights,
                projector: model.projector,
                startupTimeoutSeconds: BuiltInRealtimeTranscriptionClient.Tuning().minimumStartupTimeoutSeconds
            )
        }
    }
}

/// The recovery path for built-in dictation: the hold's recording, transcribed in one request.
enum BuiltInDictationRecovery {
    static func transcribe(
        recordingURL: URL,
        model: BuiltInDictationModel = .recommended,
        server: BuiltInModelServer = .dictation,
        writesTraditionalChinese: Bool = BuiltInDictationScript.writesTraditionalChinese()
    ) async throws -> String {
        let wav = try wavData(fromRecordingAt: recordingURL)
        let tuning = BuiltInRealtimeTranscriptionClient.Tuning()
        let connection = try await server.connection(
            for: model.weights,
            projector: model.projector,
            startupTimeoutSeconds: tuning.minimumStartupTimeoutSeconds
        )
        let text = try await BuiltInSpeechRecognizer(
            connection: connection,
            modelID: model.weights.id,
            writesTraditionalChinese: writesTraditionalChinese
        )
        .transcribe(wav: wav, timeoutSeconds: 120)
        guard !text.isEmpty else {
            throw SpeechTranscriptionError.emptyResponse
        }
        return text
    }

    /// Recordings are AAC; llama-server reads WAV, MP3 and FLAC, so decode to 16 kHz mono PCM.
    static func wavData(fromRecordingAt url: URL) throws -> Data {
        let sampleRate = 16_000
        let file = try AVAudioFile(forReading: url)
        guard let outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: Double(sampleRate),
            channels: 1,
            interleaved: true
        ),
            let converter = AVAudioConverter(from: file.processingFormat, to: outputFormat)
        else {
            throw SpeechTranscriptionError.emptyAudio
        }

        var pcm = Data()
        var inputFinished = false
        let inputCapacity: AVAudioFrameCount = 8_192
        while true {
            let outputCapacity = AVAudioFrameCount(
                Double(inputCapacity) * outputFormat.sampleRate / file.processingFormat.sampleRate
            ) + 1
            guard let output = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: outputCapacity) else {
                throw SpeechTranscriptionError.emptyAudio
            }
            var conversionError: NSError?
            let status = converter.convert(to: output, error: &conversionError) { _, inputStatus in
                guard !inputFinished,
                      let input = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: inputCapacity),
                      (try? file.read(into: input)) != nil,
                      input.frameLength > 0
                else {
                    inputFinished = true
                    inputStatus.pointee = .endOfStream
                    return nil
                }
                inputStatus.pointee = .haveData
                return input
            }
            if let conversionError {
                throw conversionError
            }
            if output.frameLength > 0, let samples = output.int16ChannelData {
                pcm.append(UnsafeBufferPointer(start: samples[0], count: Int(output.frameLength)))
            }
            if status == .endOfStream || status == .error {
                break
            }
        }
        guard !pcm.isEmpty else {
            throw SpeechTranscriptionError.emptyAudio
        }
        return PCM16WAV.wav(fromPCM16: pcm, sampleRate: sampleRate)
    }
}
