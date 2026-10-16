import SwiftUI

/// Read-only Terms of Use or Privacy Policy with a Done button. Acceptance happens on `WelcomeTermsView`.
struct LegalDocumentSheet: View {
    let kind: LegalDocument.Kind
    let onDismiss: () -> Void

    @State private var document: LegalDocument

    init(kind: LegalDocument.Kind, onDismiss: @escaping () -> Void) {
        self.kind = kind
        self.onDismiss = onDismiss
        _document = State(initialValue: LegalDocument.loadBundled(kind))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    blocks(document.intro)
                    if !document.keyPoints.isEmpty {
                        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                            blocks(document.keyPoints)
                        }
                        .padding(Theme.Spacing.lg)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.Palette.brandGold.opacity(0.18), in: .rect(cornerRadius: Theme.Radius.card))
                    }
                    blocks(document.body)
                }
                .padding(Theme.Spacing.xl)
                .frame(maxWidth: 700)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle(kind.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onDismiss)
                }
            }
        }
    }

    private func blocks(_ blocks: [LegalDocument.Block]) -> some View {
        ForEach(blocks) { block in
            switch block.kind {
            case .heading:
                Text(block.text)
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                    .padding(.top, Theme.Spacing.sm)
            case .bullet:
                HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
                    // Numbered items already carry their own "1." prefix.
                    if block.text.first?.isNumber != true {
                        Text("\u{2022}").accessibilityHidden(true)
                    }
                    Text(markdown(block.text)).font(.body)
                }
            case .paragraph:
                Text(markdown(block.text)).font(.body)
            }
        }
    }

    private func markdown(_ text: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }
}

#Preview("Terms") {
    LegalDocumentSheet(kind: .terms, onDismiss: {})
}

#Preview("Privacy, AX5") {
    LegalDocumentSheet(kind: .privacy, onDismiss: {}).dynamicTypeSize(.accessibility5)
}
