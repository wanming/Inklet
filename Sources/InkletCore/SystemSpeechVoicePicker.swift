import Foundation
import NaturalLanguage

/// Chooses how the macOS system voice reads a text: the language the text is written in, the best
/// installed voice for it, and the speaking rate for Inklet's pronunciation speed.
public enum SystemSpeechVoicePicker {
    public enum Quality: Int, Comparable, Sendable {
        case `default` = 1
        case enhanced = 2
        case premium = 3

        public static func < (lhs: Self, rhs: Self) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    /// An installed voice, reduced to what the choice depends on.
    public struct Voice: Equatable, Sendable {
        public var identifier: String
        /// BCP 47, such as `en-US` or `zh-CN`.
        public var language: String
        public var quality: Quality
        /// Novelty voices (Bells, Bubbles, …) and Personal Voice are never picked automatically.
        public var isExcluded: Bool

        public init(identifier: String, language: String, quality: Quality, isExcluded: Bool = false) {
            self.identifier = identifier
            self.language = language
            self.quality = quality
            self.isExcluded = isExcluded
        }
    }

    /// The region a language is read in when the person's own languages say nothing about it.
    private static let defaultRegions: [String: String] = [
        "en": "US",
        "zh-Hans": "CN",
        "zh-Hant": "TW",
        "ja": "JP",
        "ko": "KR",
        "es": "ES",
        "fr": "FR",
        "de": "DE",
        "pt": "BR",
        "it": "IT",
    ]

    /// The language the text is written in, as `en`, `zh-Hans` or `zh-Hant` style codes. The
    /// person's own languages, first one first, tip the balance for short or ambiguous text.
    public static func language(of text: String, preferredLanguageCodes: [String]) -> String? {
        let recognizer = NLLanguageRecognizer()
        var hints: [NLLanguage: Double] = [:]
        for (index, code) in preferredLanguageCodes.enumerated() {
            guard let language = textLanguage(ofLocaleIdentifier: code) else { continue }
            hints[NLLanguage(rawValue: language), default: 0] += 1.0 / Double(index + 2)
        }
        if !hints.isEmpty {
            recognizer.languageHints = hints
        }
        recognizer.processString(text)
        guard let language = recognizer.dominantLanguage, language != .undetermined else {
            return preferredLanguageCodes.lazy.compactMap(textLanguage(ofLocaleIdentifier:)).first
        }
        return language.rawValue
    }

    /// The installed voice that reads `language` best: in the person's own region for that language,
    /// else the language's usual region, then the highest quality. Cantonese (zh-HK) reads Chinese
    /// only for people in Hong Kong.
    public static func bestVoice(
        for language: String,
        among voices: [Voice],
        preferredLanguageCodes: [String]
    ) -> Voice? {
        let primary = primaryLanguage(of: language)
        let preferredRegion = preferredLanguageCodes.lazy.compactMap { code -> String? in
            let locale = Locale(identifier: code)
            guard locale.language.languageCode?.identifier == primary else { return nil }
            return locale.region?.identifier
        }.first
        let defaultRegion = defaultRegions[language] ?? defaultRegions[primary]

        func rank(_ voice: Voice) -> Int? {
            let locale = Locale(identifier: voice.language)
            guard !voice.isExcluded, locale.language.languageCode?.identifier == primary else { return nil }
            let region = locale.region?.identifier
            let regionRank: Int
            if region != nil, region == preferredRegion {
                regionRank = 3
            } else if primary == "zh", region == "HK" {
                regionRank = 0
            } else if region != nil, region == defaultRegion {
                regionRank = 2
            } else {
                regionRank = 1
            }
            return regionRank * 10 + voice.quality.rawValue
        }

        var best: (voice: Voice, rank: Int)?
        for voice in voices {
            guard let voiceRank = rank(voice) else { continue }
            if best == nil || voiceRank > best!.rank {
                best = (voice, voiceRank)
            }
        }
        return best?.voice
    }

    /// The system speaking rate for a pronunciation speed, where 1.0 is the system's normal rate.
    public static func rate(forSpeed speed: Double, defaultRate: Float, minimumRate: Float, maximumRate: Float) -> Float {
        min(max(defaultRate * Float(speed), minimumRate), maximumRate)
    }

    /// `zh-Hans-CN` → `zh-Hans`, `zh-TW` → `zh-Hant`, `en-GB` → `en`.
    static func textLanguage(ofLocaleIdentifier identifier: String) -> String? {
        let locale = Locale(identifier: identifier)
        guard let code = locale.language.languageCode?.identifier else { return nil }
        guard code == "zh" else { return code }
        if let script = locale.language.script?.identifier {
            return script == "Hant" ? "zh-Hant" : "zh-Hans"
        }
        switch locale.region?.identifier {
        case "TW", "HK", "MO":
            return "zh-Hant"
        default:
            return "zh-Hans"
        }
    }

    private static func primaryLanguage(of language: String) -> String {
        Locale(identifier: language).language.languageCode?.identifier
            ?? String(language.prefix { $0 != "-" && $0 != "_" })
    }
}
