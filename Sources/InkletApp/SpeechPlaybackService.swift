import AVFoundation
import Foundation
import InkletCore

/// Plays pronunciation audio: OpenAI speech as audio data, or text read by the macOS system voice.
/// `onFinish` runs when either ends on its own, never after `stop()`.
@MainActor
final class SpeechPlaybackService: NSObject, AVAudioPlayerDelegate, AVSpeechSynthesizerDelegate {
    var onFinish: (() -> Void)?

    private var player: AVAudioPlayer?
    private let synthesizer = AVSpeechSynthesizer()
    private var utterance: AVSpeechUtterance?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func play(audioData: Data) throws {
        stop()
        let player = try AVAudioPlayer(data: audioData)
        player.delegate = self
        player.prepareToPlay()
        player.play()
        self.player = player
    }

    /// Reads `text` with the best installed system voice for the language it is written in.
    func speak(_ text: String, speed: Double) {
        stop()
        let preferredLanguageCodes = [L10n.resolvedLanguage.localeIdentifier] + Locale.preferredLanguages
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = Self.systemVoice(for: text, preferredLanguageCodes: preferredLanguageCodes)
        utterance.rate = SystemSpeechVoicePicker.rate(
            forSpeed: speed,
            defaultRate: AVSpeechUtteranceDefaultSpeechRate,
            minimumRate: AVSpeechUtteranceMinimumSpeechRate,
            maximumRate: AVSpeechUtteranceMaximumSpeechRate
        )
        self.utterance = utterance
        synthesizer.speak(utterance)
    }

    func stop() {
        player?.stop()
        player = nil
        if utterance != nil {
            utterance = nil
            synthesizer.stopSpeaking(at: .immediate)
        }
    }

    private static func systemVoice(for text: String, preferredLanguageCodes: [String]) -> AVSpeechSynthesisVoice? {
        guard let language = SystemSpeechVoicePicker.language(of: text, preferredLanguageCodes: preferredLanguageCodes)
        else {
            return nil
        }
        let installed = AVSpeechSynthesisVoice.speechVoices()
        let candidates = installed.map { voice in
            SystemSpeechVoicePicker.Voice(
                identifier: voice.identifier,
                language: voice.language,
                quality: SystemSpeechVoicePicker.Quality(voice.quality),
                isExcluded: voice.voiceTraits.contains(.isNoveltyVoice) || voice.voiceTraits.contains(.isPersonalVoice)
            )
        }
        guard let best = SystemSpeechVoicePicker.bestVoice(
            for: language,
            among: candidates,
            preferredLanguageCodes: preferredLanguageCodes
        ) else {
            return AVSpeechSynthesisVoice(language: language)
        }
        return installed.first { $0.identifier == best.identifier }
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.player = nil
            self.onFinish?()
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        utteranceDidEnd(ObjectIdentifier(utterance))
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        utteranceDidEnd(ObjectIdentifier(utterance))
    }

    /// `stop()` forgets the utterance before cancelling it, so only an utterance that ends on its own
    /// still matches here.
    private nonisolated func utteranceDidEnd(_ id: ObjectIdentifier) {
        Task { @MainActor in
            guard let utterance = self.utterance, ObjectIdentifier(utterance) == id else { return }
            self.utterance = nil
            self.onFinish?()
        }
    }
}

private extension SystemSpeechVoicePicker.Quality {
    init(_ quality: AVSpeechSynthesisVoiceQuality) {
        switch quality {
        case .premium:
            self = .premium
        case .enhanced:
            self = .enhanced
        default:
            self = .default
        }
    }
}
