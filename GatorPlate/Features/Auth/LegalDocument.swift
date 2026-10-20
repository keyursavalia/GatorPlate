import Foundation

/// Parses a bundled legal document (`TermsOfUse.md`, `PrivacyPolicy.md`) into simple blocks so it can be rendered
/// as accessible, Dynamic Type safe text.
nonisolated struct LegalDocument {
    enum Kind: String, Identifiable {
        case terms, privacy

        var id: String { rawValue }

        var title: String {
            switch self {
            case .terms: "Terms of Use"
            case .privacy: "Privacy Policy"
            }
        }

        fileprivate var resourceName: String {
            switch self {
            case .terms: "TermsOfUse"
            case .privacy: "PrivacyPolicy"
            }
        }
    }

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

    /// `supportEmail` is Remote Config `support_email`, so the owner can change the mailbox without a build.
    static func loadBundled(_ kind: Kind, teamName: String = AppConfig.teamName,
                            supportEmail: String = AppConfig.supportEmail) -> LegalDocument {
        guard let url = Bundle.main.url(forResource: kind.resourceName, withExtension: "md"),
              let markdown = try? String(contentsOf: url, encoding: .utf8) else {
            return LegalDocument(body: [Block(id: 0, kind: .paragraph, text: "The \(kind.title) could not be loaded.")])
        }
        return parse(markdown, teamName: teamName, supportEmail: supportEmail)
    }

    static func parse(_ markdown: String, teamName: String = AppConfig.teamName,
                      supportEmail: String = AppConfig.supportEmail) -> LegalDocument {
        var sections: [[Block]] = [[]]
        var paragraph: [String] = []
        var nextID = 0

        func append(_ kind: Block.Kind, _ text: String) {
            let filled = substitute(text, teamName: teamName, supportEmail: supportEmail)
            sections[sections.count - 1].append(Block(id: nextID, kind: kind, text: filled))
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

        guard sections.count >= 3 else { return LegalDocument(body: sections.flatMap { $0 }) }
        return LegalDocument(intro: sections[0], keyPoints: sections[1], body: sections.dropFirst(2).flatMap { $0 })
    }

    /// Fills [TEAM NAME] and [CONTACT EMAIL]. No placeholder may stay visible (App Review 1.2 needs real contact
    /// details): DEBUG builds stop here if one survives.
    static func substitute(_ text: String, teamName: String, supportEmail: String) -> String {
        let result = text
            .replacingOccurrences(of: "[TEAM NAME]", with: teamName)
            .replacingOccurrences(of: "[CONTACT EMAIL]", with: supportEmail)
        assert(!result.contains("[TEAM NAME]") && !result.contains("[CONTACT EMAIL]"), "Legal placeholder left visible")
        return result
    }

    /// The first heading that starts with `prefix` (e.g. "11." for Community guidelines), to scroll to it.
    func headingID(startingWith prefix: String) -> Int? {
        body.first { $0.kind == .heading && $0.text.hasPrefix(prefix) }?.id
    }
}
