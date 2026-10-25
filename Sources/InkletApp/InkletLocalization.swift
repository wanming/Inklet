import Foundation
import InkletCore

enum InterfaceLanguage: String, CaseIterable, Identifiable {
    case system
    case english
    case simplifiedChinese
    case traditionalChinese
    case japanese
    case korean
    case spanish
    case french
    case german
    case portuguese
    case italian

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: "System"
        case .english: "English"
        case .simplifiedChinese: "简体中文"
        case .traditionalChinese: "繁體中文"
        case .japanese: "日本語"
        case .korean: "한국어"
        case .spanish: "Español"
        case .french: "Français"
        case .german: "Deutsch"
        case .portuguese: "Português"
        case .italian: "Italiano"
        }
    }

    var localizedDisplayName: String {
        switch self {
        case .system: L10n.text("language.system")
        case .english: "English"
        case .simplifiedChinese: "简体中文"
        case .traditionalChinese: "繁體中文"
        case .japanese: "日本語"
        case .korean: "한국어"
        case .spanish: "Español"
        case .french: "Français"
        case .german: "Deutsch"
        case .portuguese: "Português"
        case .italian: "Italiano"
        }
    }

    var localeIdentifier: String {
        switch self {
        case .system: Locale.preferredLanguages.first ?? "en"
        case .english: "en"
        case .simplifiedChinese: "zh-Hans"
        case .traditionalChinese: "zh-Hant"
        case .japanese: "ja"
        case .korean: "ko"
        case .spanish: "es"
        case .french: "fr"
        case .german: "de"
        case .portuguese: "pt"
        case .italian: "it"
        }
    }
}

enum InkletLanguageStore {
    static var selectedLanguage: InterfaceLanguage {
        get {
            guard let rawValue = UserDefaults.standard.string(forKey: InkletPreferenceKeys.interfaceLanguage) else {
                return .english
            }
            return InterfaceLanguage(rawValue: rawValue) ?? .english
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: InkletPreferenceKeys.interfaceLanguage)
            NotificationCenter.default.post(name: .inkletLanguageDidChange, object: nil)
        }
    }

    /// The language the rewrite mode writes in. Summaries and translations use the interface language.
    static var writingLanguage: SelectionTranslationLanguage {
        get {
            SelectionTranslationLanguage.writingLanguage(
                rawValue: UserDefaults.standard.string(forKey: InkletPreferenceKeys.writingLanguage)
            )
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: InkletPreferenceKeys.writingLanguage)
            NotificationCenter.default.post(name: .inkletLanguageDidChange, object: nil)
        }
    }
}

enum L10n {
    static func text(_ key: String) -> String {
        let language = resolvedLanguage
        if let value = translationTables[language]?[key] {
            return value
        }
        return en[key] ?? zhHans[key] ?? key
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: text(key), locale: Locale(identifier: resolvedLanguage.localeIdentifier), arguments: arguments)
    }

    static var resolvedLanguage: InterfaceLanguage {
        let selectedLanguage = InkletLanguageStore.selectedLanguage
        return selectedLanguage == .system
            ? resolveLanguage(preferredLanguages: Locale.preferredLanguages)
            : selectedLanguage
    }

    static func resolveLanguage(preferredLanguages: [String]) -> InterfaceLanguage {
        for identifier in preferredLanguages {
            let components = identifier.lowercased().replacingOccurrences(of: "_", with: "-").split(separator: "-")
            switch components.first {
            case "en": return .english
            case "zh":
                if components.contains("hans") { return .simplifiedChinese }
                if components.contains("hant") || components.contains(where: { ["tw", "hk", "mo"].contains($0) }) {
                    return .traditionalChinese
                }
                return .simplifiedChinese
            case "ja": return .japanese
            case "ko": return .korean
            case "es": return .spanish
            case "fr": return .french
            case "de": return .german
            case "pt": return .portuguese
            case "it": return .italian
            default: continue
            }
        }
        return .english
    }

    // Each language table lives in Localization/L10n+<table>.swift.
    static var translationTables: [InterfaceLanguage: [String: String]] {
        [
            .english: en,
            .simplifiedChinese: zhHans,
            .traditionalChinese: zhHant,
            .japanese: ja,
            .korean: ko,
            .spanish: es,
            .french: fr,
            .german: de,
            .portuguese: pt,
            .italian: it
        ]
    }
}

extension Notification.Name {
    static let inkletLanguageDidChange = Notification.Name("InkletLanguageDidChange")
}

extension PromptMode {
    /// Built-in modes show a translated name until the user renames them.
    var localizedName: String {
        guard PromptModeStore.isDefaultName(name, modeID: id) else {
            return name
        }
        switch id {
        case PromptMode.rewriteID:
            return L10n.format("prompt.rewrite.name", InkletLanguageStore.writingLanguage.nameInInterfaceLanguage)
        case PromptMode.summaryID:
            return L10n.text("prompt.summary.name")
        case PromptMode.voiceCleanupID:
            return L10n.text("prompt.voiceCleanup.name")
        default:
            return name
        }
    }
}

extension AppConfig {
    /// "My language" follows the selection translation language, which defaults to the interface language.
    var promptLanguages: PromptLanguages {
        PromptLanguages(
            myLanguage: selectionActions.translationLanguage.resolvedPromptTargetName(
                interfaceLanguageCode: L10n.resolvedLanguage.localeIdentifier
            ),
            writingLanguage: InkletLanguageStore.writingLanguage.promptTargetName
        )
    }
}

extension SelectionTranslationLanguage {
    var localizedDisplayName: String {
        switch self {
        case .followInterfaceLanguage: L10n.text("selection.language.followInterface")
        case .english: "English"
        case .simplifiedChinese: "简体中文"
        case .traditionalChinese: "繁體中文"
        case .japanese: "日本語"
        case .korean: "한국어"
        case .spanish: "Español"
        case .french: "Français"
        case .german: "Deutsch"
        case .portuguese: "Português"
        case .italian: "Italiano"
        }
    }

    /// The language's name as a word in the interface language, such as "Japanese" or "日语".
    var nameInInterfaceLanguage: String {
        guard let languageCode else { return promptTargetName }
        return Locale(identifier: L10n.resolvedLanguage.localeIdentifier)
            .localizedString(forLanguageCode: languageCode) ?? promptTargetName
    }
}

extension VoiceInputConfig.Shortcut {
    var localizedName: String {
        switch self {
        case .rightOption:
            L10n.text("settings.voice.shortcut.rightOption")
        case .rightCommand:
            L10n.text("settings.voice.shortcut.rightCommand")
        case .leftOption:
            L10n.text("settings.voice.shortcut.leftOption")
        case .leftCommand:
            L10n.text("settings.voice.shortcut.leftCommand")
        case .disabled:
            L10n.text("settings.voice.shortcut.disabled")
        }
    }
}

extension HotkeyError {
    var userFacingMessage: String {
        switch self {
        case .unsupported(let value):
            L10n.format("hotkey.error.unsupported", value)
        case .registrationFailed(let status):
            L10n.format("hotkey.error.registrationFailed", Int(status))
        }
    }
}
