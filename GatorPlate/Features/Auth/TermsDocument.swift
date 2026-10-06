import Foundation

/// Parses the bundled `TermsOfUse.md` into simple blocks so it can be rendered as accessible, Dynamic Type safe text.
nonisolated struct TermsDocument {
    struct Block: Identifiable {
        enum Kind { case heading, bullet, paragraph }
        let id: Int
        let kind: Kind
        let text: String
    }

    /// Title area (version and date).
    var intro: [Block] = []
    /// The "Key points" summary shown at the top.
    var keyPoints: [Block] = []
    var body: [Block] = []

    static func loadBundled() -> TermsDocument {
        guard let url = Bundle.main.url(forResource: "TermsOfUse", withExtension: "md"),
              let markdown = try? String(contentsOf: url, encoding: .utf8) else {
            return TermsDocument(body: [Block(id: 0, kind: .paragraph, text: "The Terms of Use could not be loaded.")])
        }
        return parse(markdown)
    }

    static func parse(_ markdown: String) -> TermsDocument {
        var sections: [[Block]] = [[]]
        var paragraph: [String] = []
        var nextID = 0

        func append(_ kind: Block.Kind, _ text: String) {
            sections[sections.count - 1].append(Block(id: nextID, kind: kind, text: substitute(text)))
            nextID += 1
        }
        func flushParagraph() {
            guard !paragraph.isEmpty else { return }
            append(.paragraph, paragraph.joined(separator: " "))
            paragraph = []
        }

        for rawLine in markdown.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty {
                flushParagraph()
            } else if line == "---" {
                flushParagraph()
                sections.append([])
            } else if line.hasPrefix("# ") {
                flushParagraph() // The document title is shown in the navigation bar.
            } else if line.hasPrefix("## ") {
                flushParagraph()
                append(.heading, String(line.dropFirst(3)))
            } else if line.hasPrefix("- ") {
                flushParagraph()
                append(.bullet, String(line.dropFirst(2)))
            } else if line.first?.isNumber == true, line.contains(". ") {
                flushParagraph()
                append(.bullet, line) // Keeps the "1." prefix.
            } else {
                paragraph.append(line)
            }
        }
        flushParagraph()

        guard sections.count >= 3 else { return TermsDocument(body: sections.flatMap { $0 }) }
        return TermsDocument(intro: sections[0], keyPoints: sections[1], body: sections.dropFirst(2).flatMap { $0 })
    }

    /// Fills [TEAM NAME] / [CONTACT EMAIL] from `AppConfig`; empty values leave the placeholder visible.
    private static func substitute(_ text: String) -> String {
        var result = text
        if !AppConfig.teamName.isEmpty { result = result.replacingOccurrences(of: "[TEAM NAME]", with: AppConfig.teamName) }
        if !AppConfig.contactEmail.isEmpty { result = result.replacingOccurrences(of: "[CONTACT EMAIL]", with: AppConfig.contactEmail) }
        return result
    }
}
