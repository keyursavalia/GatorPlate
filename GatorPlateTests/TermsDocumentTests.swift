import Testing
@testable import GatorPlate

struct TermsDocumentTests {
    private let sample = """
    ## Key points
    - First **bold** point
    - Second point

    ## 1. About
    Line one of a paragraph
    continues here.

    Second paragraph for {{TEAM_NAME}}.

    ## 2. Posting
    1. Do this
    2. Do that
    Closing line right after the list.
    """

    @Test func parsesSectionsAndBlocks() {
        let document = TermsDocument.parse(sample, replacements: ["{{TEAM_NAME}}": "Gators"])

        #expect(document.keyPoints?.blocks == [.bullet("First **bold** point"), .bullet("Second point")])
        #expect(document.fullText.map(\.title) == ["1. About", "2. Posting"])
        #expect(document.fullText[0].blocks == [
            .paragraph("Line one of a paragraph continues here."),
            .paragraph("Second paragraph for Gators.")
        ])
        #expect(document.fullText[1].blocks == [
            .numbered(1, "Do this"),
            .numbered(2, "Do that"),
            .paragraph("Closing line right after the list.")
        ])
    }

    @Test func ignoresTextBeforeFirstSection() {
        let document = TermsDocument.parse("stray line\n\n## Only\nBody")
        #expect(document.sections.map(\.title) == ["Only"])
    }

    @Test func bundledTermsLoadWithPlaceholdersFilled() throws {
        let document = try #require(TermsDocument.loadBundled(), "TermsOfUse.md must be in the app bundle")
        #expect(document.keyPoints != nil)
        #expect(document.fullText.count == 17)

        let allText = document.sections.flatMap(\.blocks).map { block -> String in
            switch block {
            case .paragraph(let text), .bullet(let text), .numbered(_, let text): text
            }
        }.joined(separator: " ")
        #expect(!allText.contains("{{"))
    }
}
