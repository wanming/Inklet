import Foundation

/// One line-level piece of a release's Markdown notes. Inline Markdown (bold, italics, code, links)
/// stays in the text and is rendered by the view.
public enum InkletReleaseNotesBlock: Equatable, Sendable {
    case heading(String)
    case bullet(String)
    case paragraph(String)
}

extension InkletReleaseNotes {
    /// Picks one language from notes written as one heading per language ("## English",
    /// "## 简体中文", …), the way every Inklet release is written. The text before the first
    /// language heading and the shared footer after the closing rule (`---`) are kept.
    /// Notes without language headings are returned unchanged.
    ///
    /// - Parameters:
    ///   - preferredHeadings: Language headings to show, best first, such as the interface
    ///     language followed by English.
    ///   - languageHeadings: Every heading that names a language section.
    public static func section(
        of notes: String,
        preferring preferredHeadings: [String],
        languageHeadings: [String]
    ) -> String {
        let lines = notes.components(separatedBy: "\n")
        let sections: [(name: String, line: Int)] = lines.indices.compactMap { index in
            guard let title = headingTitle(lines[index]),
                  let name = languageHeadings.first(where: { matches($0, title) })
            else {
                return nil
            }
            return (name: name, line: index)
        }
        guard let firstSection = sections.first, let lastSection = sections.last else {
            return notes
        }

        let footerRule = lines[(lastSection.line + 1)...].firstIndex(where: isThematicBreak)
        let bodyEnd = footerRule ?? lines.endIndex

        let chosen = preferredHeadings.lazy.compactMap { preferred in
            sections.firstIndex { matches($0.name, preferred) }
        }.first ?? 0
        let start = sections[chosen].line + 1
        let end = chosen + 1 < sections.count ? sections[chosen + 1].line : bodyEnd
        var body = Array(lines[start..<end])
        while let last = body.last, last.trimmingCharacters(in: .whitespaces).isEmpty || isThematicBreak(last) {
            body.removeLast()
        }

        let intro = lines[..<firstSection.line].joined(separator: "\n")
        let footer = footerRule.map { lines[($0 + 1)...].joined(separator: "\n") } ?? ""
        return [intro, body.joined(separator: "\n"), footer]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }

    /// Splits Markdown notes into headings, list items and paragraphs. Rules (`---`) are dropped,
    /// and the lines of one paragraph stay on their own lines, as GitHub shows release notes.
    public static func blocks(_ markdown: String) -> [InkletReleaseNotesBlock] {
        var blocks: [InkletReleaseNotesBlock] = []
        var paragraph: [String] = []

        func flushParagraph() {
            if !paragraph.isEmpty {
                blocks.append(.paragraph(paragraph.joined(separator: "\n")))
                paragraph.removeAll()
            }
        }

        for line in markdown.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || isThematicBreak(trimmed) {
                flushParagraph()
            } else if let title = headingTitle(trimmed) {
                flushParagraph()
                blocks.append(.heading(title))
            } else if let item = bulletText(trimmed) {
                flushParagraph()
                blocks.append(.bullet(item))
            } else {
                paragraph.append(trimmed)
            }
        }
        flushParagraph()
        return blocks
    }

    private static func headingTitle(_ line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let hashes = trimmed.prefix { $0 == "#" }
        guard (1...6).contains(hashes.count) else {
            return nil
        }
        let rest = trimmed.dropFirst(hashes.count)
        guard rest.first == " " else {
            return nil
        }
        let title = rest.trimmingCharacters(in: .whitespaces)
        return title.isEmpty ? nil : title
    }

    private static func bulletText(_ line: String) -> String? {
        guard let marker = line.first, "-*+".contains(marker),
              line.dropFirst().first == " "
        else {
            return nil
        }
        let text = line.dropFirst(2).trimmingCharacters(in: .whitespaces)
        return text.isEmpty ? nil : text
    }

    private static func isThematicBreak(_ line: String) -> Bool {
        let characters = line.filter { !$0.isWhitespace }
        guard characters.count >= 3, let first = characters.first, "-*_".contains(first) else {
            return false
        }
        return characters.allSatisfy { $0 == first }
    }

    private static func matches(_ heading: String, _ title: String) -> Bool {
        heading.compare(title, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
    }
}
