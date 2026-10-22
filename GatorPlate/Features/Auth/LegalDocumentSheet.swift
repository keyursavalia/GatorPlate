import SwiftUI

/// Read-only Terms of Use or Privacy Policy with a Done button. Acceptance happens on `WelcomeTermsView`.
/// `startSection` (a heading prefix like "11.") opens it scrolled to that section.
struct LegalDocumentSheet: View {
    let kind: LegalDocument.Kind
    var startSection: String?
    let onDismiss: () -> Void

    @State private var document: LegalDocument
    @Environment(\.appEnvironment) private var environment

    init(kind: LegalDocument.Kind, startSection: String? = nil, onDismiss: @escaping () -> Void) {
        self.kind = kind
        self.startSection = startSection
        self.onDismiss = onDismiss
        _document = State(initialValue: LegalDocument.loadBundled(kind))
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                content
                    .task {
                        // The remote support address replaces the in-app default.
                        document = LegalDocument.loadBundled(kind, supportEmail: environment.runtime.current.supportEmail)
                        if let startSection, let id = document.headingID(startingWith: startSection) {
                            proxy.scrollTo(id, anchor: .top)
                        }
                    }
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

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                blocks(document.intro)
                blocks(document.body)
            }
            .padding(Theme.Spacing.xl)
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
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
                    .id(block.id)
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
