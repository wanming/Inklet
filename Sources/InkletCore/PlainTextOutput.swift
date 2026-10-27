import Foundation

/// Results are inserted into ordinary text fields, but models (small local ones especially) often answer
/// in Markdown even when the prompt says not to. This turns that Markdown into plain text, keeping any
/// kind of Markdown the user's own text already uses, and leaves everything alone when the prompt asks for Markdown.
public enum PlainTextOutput {
    static let promptInstruction = "Return plain text only, without Markdown formatting."

    enum Syntax: CaseIterable {
        case codeFence
        case heading
        case horizontalRule
        case blockquote
        case bullet
        case bold
        case italic
        case inlineCode
        case link
    }

    /// The system prompt actually sent: asks for plain text unless the prompt wants Markdown or the source already uses it.
    public static func systemPrompt(_ systemPrompt: String, sourceText: String) -> String {
        guard !promptRequestsMarkdown(systemPrompt), syntaxUsed(in: sourceText).isEmpty else {
            return systemPrompt
        }
        return systemPrompt + "\n" + promptInstruction
    }

    public static func clean(_ output: String, sourceText: String, systemPrompt: String) -> String {
        guard !promptRequestsMarkdown(systemPrompt) else { return output }
        return clean(output, keeping: syntaxUsed(in: sourceText))
    }

    static func clean(_ output: String, keeping kept: Set<Syntax>) -> String {
        let strips = Set(Syntax.allCases).subtracting(kept)
        guard !strips.isEmpty else { return output }

        var lines: [String] = []
        var isInsideFence = false
        for line in output.components(separatedBy: "\n") {
            if matches(Pattern.codeFence, line) {
                isInsideFence.toggle()
                if !strips.contains(.codeFence) {
                    lines.append(line)
                }
                continue
            }
            if isInsideFence {
                lines.append(line)
                continue
            }
            if strips.contains(.horizontalRule), matches(Pattern.horizontalRule, line) {
                continue
            }
            lines.append(cleanLine(line, strips: strips))
        }
        return lines.joined(separator: "\n")
    }

    static func syntaxUsed(in text: String) -> Set<Syntax> {
        var used = Set<Syntax>()
        for line in text.components(separatedBy: "\n") {
            for syntax in Syntax.allCases where !used.contains(syntax) && matches(Pattern.detection(syntax), line) {
                used.insert(syntax)
            }
        }
        return used
    }

    /// A custom prompt may ask for Markdown on purpose ("format it as a Markdown table"); the built-in ones only forbid it.
    /// Each sentence is judged on its own, so "Use a Markdown list. Do not explain." still asks for Markdown.
    static func promptRequestsMarkdown(_ systemPrompt: String) -> Bool {
        systemPrompt.components(separatedBy: sentenceEnds).contains { sentence in
            sentence.range(of: "markdown", options: .caseInsensitive) != nil && !matches(Pattern.negation, sentence)
        }
    }

    private static let sentenceEnds = CharacterSet.newlines.union(CharacterSet(charactersIn: ".!?;。！？；，"))

    private static func cleanLine(_ line: String, strips: Set<Syntax>) -> String {
        var line = line
        if strips.contains(.heading) {
            line = replacing(Pattern.heading, in: line, with: "$1")
        }
        if strips.contains(.blockquote) {
            line = replacing(Pattern.blockquote, in: line, with: "")
        }
        if strips.contains(.bullet) {
            line = replacing(Pattern.bullet, in: line, with: "$1• ")
        }
        if strips.contains(.inlineCode) {
            line = replacing(Pattern.inlineCode, in: line, with: "$1")
        }
        if strips.contains(.bold) {
            line = replacing(Pattern.boldItalic, in: line, with: "$1")
            line = replacing(Pattern.bold, in: line, with: "$1")
            line = replacing(Pattern.underscoreBold, in: line, with: "$1")
        }
        if strips.contains(.italic) {
            line = replacing(Pattern.italic, in: line, with: "$1")
        }
        if strips.contains(.link) {
            line = replacingLinks(in: line)
        }
        return line
    }

    private static func replacingLinks(in line: String) -> String {
        let range = NSRange(line.startIndex..., in: line)
        var result = line
        for match in Pattern.link.matches(in: line, range: range).reversed() {
            guard let whole = Range(match.range, in: line),
                  let text = Range(match.range(at: 1), in: line),
                  let url = Range(match.range(at: 2), in: line)
            else { continue }
            let replacement = line[text] == line[url] ? String(line[url]) : "\(line[text]) (\(line[url]))"
            result.replaceSubrange(whole, with: replacement)
        }
        return result
    }

    private static func matches(_ regex: NSRegularExpression, _ line: String) -> Bool {
        regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) != nil
    }

    private static func replacing(_ regex: NSRegularExpression, in line: String, with template: String) -> String {
        regex.stringByReplacingMatches(in: line, range: NSRange(line.startIndex..., in: line), withTemplate: template)
    }

    private enum Pattern {
        static let codeFence = regex(#"^[ \t]*```[^`]*$"#)
        static let heading = regex(#"^[ \t]{0,3}#{1,6}[ \t]+(.*?)(?:[ \t]+#+)?[ \t]*$"#)
        static let horizontalRule = regex(#"^[ \t]*([-*_])(?:[ \t]*\1){2,}[ \t]*$"#)
        static let blockquote = regex(#"^[ \t]*>[ \t]?"#)
        static let bullet = regex(#"^([ \t]*)[-*+][ \t]+"#)
        static let boldItalic = regex(#"\*\*\*(?=\S)(.+?)(?<=\S)\*\*\*"#)
        static let bold = regex(#"\*\*(?=\S)(.+?)(?<=\S)\*\*"#)
        static let underscoreBold = regex(#"(?<!\w)__(?=\S)(.+?)(?<=\S)__(?!\w)"#)
        static let italic = regex(#"(?<![*\w])\*(?=[^\s*])([^*]+?)(?<=[^\s*])\*(?![*\w])"#)
        static let inlineCode = regex(#"`([^`]+)`"#)
        static let link = regex(#"\[([^\]]+)\]\((\S+?)\)"#)
        static let negation = regex(
            #"(?i)\b(?:not|no|without|never|avoid|nicht|ohne|keine?[nm]?|sin|nunca|sans|pas|jamais|senza|mai|sem|não)\b|n't|plain text|[不别別勿无無]|禁止|ない|なし|않|없|마세요|말고"#
        )

        static func detection(_ syntax: Syntax) -> NSRegularExpression {
            switch syntax {
            case .codeFence: codeFence
            case .heading: heading
            case .horizontalRule: horizontalRule
            case .blockquote: blockquote
            case .bullet: bullet
            case .bold: anyBold
            case .italic: italic
            case .inlineCode: inlineCode
            case .link: link
            }
        }

        private static let anyBold = regex(#"\*\*(?=\S)(.+?)(?<=\S)\*\*|(?<!\w)__(?=\S)(.+?)(?<=\S)__(?!\w)"#)

        private static func regex(_ pattern: String) -> NSRegularExpression {
            // The patterns are constants, so a failure here is a programming error caught by the tests.
            try! NSRegularExpression(pattern: pattern)
        }
    }
}
