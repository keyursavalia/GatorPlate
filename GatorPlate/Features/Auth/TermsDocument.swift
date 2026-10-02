import Foundation
import OSLog

/// Parsed Terms of Use, loaded from the bundled `Resources/TermsOfUse.md` so the text can change
/// without code changes. Supports only what the file uses: `## ` headings, `- ` bullets,
/// `1. ` numbered items, paragraphs, and inline `**bold**`.
nonisolated struct TermsDocument: Equatable, Sendable {
    enum Block: Equatable, Sendable {
        case paragraph(String)
        case bullet(String)
        case numbered(Int, String)
    }

    struct Section: Equatable, Sendable, Identifiable {
        var title: String
        var blocks: [Block]
        var id: String { title }
    }

    /// The first section in the file; shown as a summary card above the full text.
    static let keyPointsTitle = "Key points"

    var sections: [Section]

    var keyPoints: Section? { sections.first { $0.title == Self.keyPointsTitle } }
    var fullText: [Section] { sections.filter { $0.title != Self.keyPointsTitle } }

    static func parse(_ markdown: String, replacements: [String: String] = [:]) -> TermsDocument {
        var text = markdown
        for (token, value) in replacements {
            text = text.replacingOccurrences(of: token, with: value)
        }

        var sections: [Section] = []
        var paragraph: [String] = []

        func flushParagraph() {
            guard !paragraph.isEmpty, !sections.isEmpty else {
                paragraph = []
                return
            }
            sections[sections.count - 1].blocks.append(.paragraph(paragraph.joined(separator: " ")))
            paragraph = []
        }

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty {
                flushParagraph()
            } else if line.hasPrefix("## ") {
                flushParagraph()
                let title = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                sections.append(Section(title: title, blocks: []))
            } else if line.hasPrefix("- ") {
                flushParagraph()
                if !sections.isEmpty {
                    sections[sections.count - 1].blocks.append(.bullet(String(line.dropFirst(2))))
                }
            } else if let (number, item) = numberedItem(line) {
                flushParagraph()
                if !sections.isEmpty {
                    sections[sections.count - 1].blocks.append(.numbered(number, item))
                }
            } else {
                paragraph.append(line)
            }
        }
        flushParagraph()
        return TermsDocument(sections: sections)
    }

    /// Loads the bundled file, or nil (and logs) if it is missing.
    static func loadBundled(bundle: Bundle = .main) -> TermsDocument? {
        guard
            let url = bundle.url(forResource: "TermsOfUse", withExtension: "md"),
            let markdown = try? String(contentsOf: url, encoding: .utf8)
        else {
            Logger.app.error("TermsOfUse.md missing from bundle")
            return nil
        }
        return parse(markdown, replacements: [
            "{{TEAM_NAME}}": AppConfig.teamName,
            "{{CONTACT_EMAIL}}": AppConfig.contactEmail
        ])
    }

    private static func numberedItem(_ line: String) -> (Int, String)? {
        guard let dot = line.firstIndex(of: "."), dot != line.startIndex else { return nil }
        let prefix = line[line.startIndex..<dot]
        guard let number = Int(prefix) else { return nil }
        let rest = line[line.index(after: dot)...]
        guard rest.hasPrefix(" ") else { return nil }
        return (number, rest.trimmingCharacters(in: .whitespaces))
    }
}
