public struct PromptMode: Codable, Equatable, Identifiable, Sendable {
    public static let autoID = "auto"
    public static let chineseToEnglishID = "chinese-to-english"
    public static let polishEnglishID = "polish-english"
    public static let customPromptID = "custom-prompt"

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
                id: PromptMode.autoID,
                name: "Auto",
                description: "根据输入语言自动选择转换模式",
                systemPrompt: "",
                shortcut: nil,
                participatesInAuto: false,
                autoRule: .none,
                sortOrder: 0,
                isVisible: true
            ),
            PromptMode(
                id: PromptMode.chineseToEnglishID,
                name: "Chinese to English",
                description: "把中文原意翻译成自然英文",
                systemPrompt: "Translate the user's Chinese text into natural English. Preserve meaning and tone. Return only the translated text.",
                shortcut: "⌘1",
                participatesInAuto: true,
                autoRule: .chineseHeavy,
                sortOrder: 1,
                isVisible: true
            ),
            PromptMode(
                id: PromptMode.polishEnglishID,
                name: "Polish English",
                description: "润色英文，修正语法和表达",
                systemPrompt: "Improve the user's English. Fix grammar, spelling, word choice, and clarity while preserving meaning. Return only the improved text.",
                shortcut: "⌘2",
                participatesInAuto: true,
                autoRule: .englishHeavy,
                sortOrder: 2,
                isVisible: true
            ),
            PromptMode(
                id: PromptMode.customPromptID,
                name: "Custom Prompt",
                description: "使用用户自定义 prompt",
                systemPrompt: "Transform the user's text according to the user's custom instruction. Return only the transformed text.",
                shortcut: "⌘3",
                participatesInAuto: false,
                autoRule: .none,
                sortOrder: 3,
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
        if modeID != PromptMode.autoID, let mode = mode(id: modeID) {
            return mode
        }

        let rule: PromptMode.AutoRule = sourceText.isChineseHeavy ? .chineseHeavy : .englishHeavy
        return modes.first { $0.participatesInAuto && $0.autoRule == rule }
            ?? modes.first { $0.id == PromptMode.polishEnglishID }
            ?? PromptModeStore.defaultPolishEnglishMode
    }

    private static var defaultPolishEnglishMode: PromptMode {
        PromptMode(
            id: PromptMode.polishEnglishID,
            name: "Polish English",
            description: "润色英文，修正语法和表达",
            systemPrompt: "Improve the user's English. Fix grammar, spelling, word choice, and clarity while preserving meaning. Return only the improved text.",
            shortcut: "⌘2",
            participatesInAuto: true,
            autoRule: .englishHeavy,
            sortOrder: 2,
            isVisible: true
        )
    }
}

private extension String {
    var isChineseHeavy: Bool {
        let scalars = unicodeScalars.filter { !$0.properties.isWhitespace }
        guard !scalars.isEmpty else { return false }

        let chineseCount = scalars.filter { scalar in
            (0x4E00...0x9FFF).contains(Int(scalar.value))
        }.count
        return Double(chineseCount) / Double(scalars.count) >= 0.25
    }
}
