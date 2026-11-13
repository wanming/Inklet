import Foundation

/// A saved piece of text the person pastes from the ⌥⇧V panel or by typing its keyword.
public struct Snippet: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var text: String
    /// Typed anywhere, the keyword is replaced with the text when keyword expansion is on.
    /// Empty means no keyword.
    public var keyword: String
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        text: String,
        keyword: String = "",
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.name = name
        self.text = text
        self.keyword = keyword
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// The name, or the first line of the text while the snippet is unnamed.
    public var displayName: String {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedName.isEmpty {
            return trimmedName
        }
        return text
            .split(whereSeparator: \.isNewline)
            .lazy
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty } ?? ""
    }
}

public enum SnippetKeywordIssue: Equatable, Sendable {
    case containsWhitespace
    case tooShort
    case duplicate(name: String)
}

public enum SnippetDefaults {
    /// Typing keywords watches every keystroke, so it stays off until the person turns it on.
    public static let expandsKeywords = false
    public static let minimumKeywordLength = 2
    public static let maximumKeywordLength = 32
}

/// Snippets kept on this Mac in one JSON file, sorted by name.
@MainActor
public final class SnippetStore {
    public private(set) var snippets: [Snippet] = []
    /// Runs after every change, on the main actor.
    public var onChange: (() -> Void)?

    private let fileURL: URL
    private let fileManager: FileManager
    private let now: () -> Date

    public init(
        fileURL: URL,
        fileManager: FileManager = .default,
        now: @escaping () -> Date = Date.init
    ) {
        self.fileURL = fileURL
        self.fileManager = fileManager
        self.now = now
    }

    /// Reads the saved snippets; a missing or unreadable file starts an empty list.
    public func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([Snippet].self, from: data)
        else {
            snippets = []
            return
        }
        snippets = Self.sorted(decoded)
    }

    @discardableResult
    public func add(name: String = "", text: String = "", keyword: String = "") -> Snippet {
        let date = now()
        let snippet = Snippet(name: name, text: text, keyword: keyword, createdAt: date, updatedAt: date)
        snippets = Self.sorted(snippets + [snippet])
        save()
        onChange?()
        return snippet
    }

    public func update(_ snippet: Snippet) {
        guard let index = snippets.firstIndex(where: { $0.id == snippet.id }),
              snippets[index] != snippet
        else {
            return
        }
        var updated = snippet
        updated.updatedAt = now()
        snippets[index] = updated
        snippets = Self.sorted(snippets)
        save()
        onChange?()
    }

    public func delete(id: UUID) {
        guard snippets.contains(where: { $0.id == id }) else {
            return
        }
        snippets.removeAll { $0.id == id }
        save()
        onChange?()
    }

    public func snippet(id: UUID) -> Snippet? {
        snippets.first { $0.id == id }
    }

    /// Why a keyword can't be used, or nil when it can (an empty keyword is fine: no keyword).
    public func keywordIssue(_ keyword: String, for snippetID: UUID) -> SnippetKeywordIssue? {
        guard !keyword.isEmpty else {
            return nil
        }
        if keyword.contains(where: { $0.isWhitespace || $0.isNewline }) {
            return .containsWhitespace
        }
        if keyword.count < SnippetDefaults.minimumKeywordLength {
            return .tooShort
        }
        if let other = snippets.first(where: { $0.id != snippetID && $0.keyword == keyword }) {
            return .duplicate(name: other.displayName)
        }
        return nil
    }

    /// The snippet whose keyword was just typed: the longest valid keyword the typed text ends with.
    public func snippet(endingTypedText typedText: String) -> Snippet? {
        snippets
            .filter { snippet in
                !snippet.keyword.isEmpty
                    && keywordIssue(snippet.keyword, for: snippet.id) == nil
                    && typedText.hasSuffix(snippet.keyword)
            }
            .max { $0.keyword.count < $1.keyword.count }
    }

    /// Snippets whose name, keyword or text matches every word of the query.
    public static func filter(_ snippets: [Snippet], query: String) -> [Snippet] {
        let words = query.split(whereSeparator: \.isWhitespace).map(String.init)
        guard !words.isEmpty else {
            return snippets
        }
        return snippets.filter { snippet in
            let haystack = [snippet.name, snippet.keyword, snippet.text].joined(separator: "\n")
            return words.allSatisfy { word in
                haystack.range(of: word, options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive]) != nil
            }
        }
    }

    static func sorted(_ snippets: [Snippet]) -> [Snippet] {
        snippets.sorted { lhs, rhs in
            let order = lhs.displayName.localizedStandardCompare(rhs.displayName)
            return order == .orderedSame ? lhs.createdAt < rhs.createdAt : order == .orderedAscending
        }
    }

    private func save() {
        do {
            try fileManager.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try JSONEncoder().encode(snippets).write(to: fileURL, options: .atomic)
        } catch {
            NSLog("Snippets could not be saved: \(error)")
        }
    }
}

/// The characters typed since the last caret jump, for spotting a snippet keyword. Everything that
/// can move the caret or change text elsewhere (arrows, Return, clicks, shortcuts) clears it.
public struct SnippetTypingBuffer: Equatable, Sendable {
    public enum Input: Equatable, Sendable {
        case characters(String)
        case deleteBackward
        case reset
    }

    public static let capacity = 64

    public private(set) var text = ""

    public init() {}

    public mutating func handle(_ input: Input) {
        switch input {
        case .characters(let characters):
            guard !characters.isEmpty,
                  !characters.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) })
            else {
                text = ""
                return
            }
            text += characters
            if text.count > Self.capacity {
                text = String(text.suffix(Self.capacity))
            }
        case .deleteBackward:
            if !text.isEmpty {
                text.removeLast()
            }
        case .reset:
            text = ""
        }
    }
}
