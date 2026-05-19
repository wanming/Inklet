public struct PromptMode: Codable, Equatable, Identifiable, Sendable {
    public static let autoID = "auto"
    public static let translateToEnglishID = "translate-to-english"
    public static let improveWritingID = "improve-writing"
    public static let makeConciseID = "make-concise"
    public static let professionalToneID = "professional-tone"
    public static let friendlyReplyID = "friendly-reply"
    public static let customPromptID = "custom-prompt"
    public static let chineseToEnglishID = "chinese-to-english"
    public static let polishEnglishID = "polish-english"

    public enum AutoRule: String, Codable, Sendable {
        case none
        case chineseHeavy
        case englishHeavy

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let rawValue = try container.decode(String.self)
            self = AutoRule(rawValue: rawValue) ?? .none
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(rawValue)
        }
    }

    public var id: String
    public var name: String
    public var description: String
    public var systemPrompt: String
    public var shortcut: String?
    public var participatesInAuto: Bool
    public var autoRule: AutoRule
    public var sortOrder: Int
    public var isVisible: Bool

    public init(
        id: String,
        name: String,
        description: String,
        systemPrompt: String,
        shortcut: String?,
        participatesInAuto: Bool,
        autoRule: AutoRule,
        sortOrder: Int,
        isVisible: Bool
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.systemPrompt = systemPrompt
        self.shortcut = shortcut
        self.participatesInAuto = participatesInAuto
        self.autoRule = autoRule
        self.sortOrder = sortOrder
        self.isVisible = isVisible
    }
}

public struct PromptModeStore: Equatable, Sendable {
    private(set) public var modes: [PromptMode]

    public var visibleModes: [PromptMode] {
        modes
            .filter(\.isVisible)
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    public init(modes: [PromptMode]) {
        self.modes = modes
    }

    public static func defaultStore() -> PromptModeStore {
        PromptModeStore(modes: [
            PromptMode(
                id: PromptMode.translateToEnglishID,
                name: "Translate to English",
                description: "把任意语言翻译成自然英文",
                systemPrompt: "Translate the user's text into natural English. Preserve meaning, tone, names, formatting, and intent. Return only the translated text.",
                shortcut: "⌘1",
                participatesInAuto: false,
                autoRule: .none,
                sortOrder: 0,
                isVisible: true
            ),
            PromptMode(
                id: PromptMode.improveWritingID,
                name: "Improve Writing",
                description: "保持原语言，润色语法、表达和清晰度",
                systemPrompt: "Improve the user's writing while keeping the original language. Fix grammar, spelling, word choice, clarity, and flow while preserving meaning and tone. Return only the improved text.",
                shortcut: "⌘2",
                participatesInAuto: false,
                autoRule: .none,
                sortOrder: 1,
                isVisible: true
            ),
            PromptMode(
                id: PromptMode.makeConciseID,
                name: "Make Concise",
                description: "保持原语言，压缩文字并保留重点",
                systemPrompt: "Make the user's text more concise while keeping the original language. Remove redundancy, keep the key points, and preserve the intended tone. Return only the concise version.",
                shortcut: "⌘3",
                participatesInAuto: false,
                autoRule: .none,
                sortOrder: 2,
                isVisible: true
            ),
            PromptMode(
                id: PromptMode.professionalToneID,
                name: "Professional Tone",
                description: "保持原语言，改成更职业、清楚、礼貌的语气",
                systemPrompt: "Rewrite the user's text in a more professional, clear, and polite tone while keeping the original language and preserving the meaning. Return only the rewritten text.",
                shortcut: "⌘4",
                participatesInAuto: false,
                autoRule: .none,
                sortOrder: 3,
                isVisible: true
            ),
            PromptMode(
                id: PromptMode.friendlyReplyID,
                name: "Friendly Reply",
                description: "保持原语言，改成自然、友好、适合回复的表达",
                systemPrompt: "Rewrite the user's text as a natural, friendly reply while keeping the original language and preserving the meaning. Return only the reply.",
                shortcut: "⌘5",
                participatesInAuto: false,
                autoRule: .none,
                sortOrder: 4,
                isVisible: true
            ),
            PromptMode(
                id: PromptMode.customPromptID,
                name: "Custom Prompt",
                description: "使用用户自定义 prompt",
                systemPrompt: "Transform the user's text according to the user's custom instruction. Return only the transformed text.",
                shortcut: "⌘6",
                participatesInAuto: false,
                autoRule: .none,
                sortOrder: 5,
                isVisible: true
            )
        ])
    }

    public mutating func upsert(_ mode: PromptMode) {
        if let index = modes.firstIndex(where: { $0.id == mode.id }) {
            modes[index] = mode
        } else {
            modes.append(mode)
        }
    }

    public func mode(id: String) -> PromptMode? {
        modes.first { $0.id == id }
    }

    public func resolve(modeID: String, sourceText: String) -> PromptMode {
        if let mode = mode(id: modeID), mode.id != PromptMode.autoID {
            return mode
        }

        return modes.first { $0.id == PromptMode.translateToEnglishID }
            ?? PromptModeStore.defaultTranslateToEnglishMode
    }

    private static var defaultTranslateToEnglishMode: PromptMode {
        PromptMode(
            id: PromptMode.translateToEnglishID,
            name: "Translate to English",
            description: "把任意语言翻译成自然英文",
            systemPrompt: "Translate the user's text into natural English. Preserve meaning, tone, names, formatting, and intent. Return only the translated text.",
            shortcut: "⌘1",
            participatesInAuto: false,
            autoRule: .none,
            sortOrder: 0,
            isVisible: true
        )
    }
}
