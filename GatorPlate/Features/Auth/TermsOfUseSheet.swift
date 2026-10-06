import SwiftUI

/// Terms of Use. As a gate (`requiresAcceptance`) the user must tick the box and tap "I agree";
/// otherwise it is read-only with a Done button.
struct TermsOfUseSheet: View {
    var requiresAcceptance = false
    var isSubmitting = false
    var errorMessage: String?
    var onAccept: () -> Void = {}
    /// Done (read-only) or "Decline and sign out" (gate).
    let onDismiss: () -> Void

    @State private var agreed = false
    @State private var document = TermsDocument.loadBundled()

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
                    if requiresAcceptance { agreement }
                }
                .padding(Theme.Spacing.xl)
                .frame(maxWidth: 700)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("Terms of Use")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !requiresAcceptance {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done", action: onDismiss)
                    }
                }
            }
        }
        .interactiveDismissDisabled(requiresAcceptance)
    }

    private func blocks(_ blocks: [TermsDocument.Block]) -> some View {
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

    private var agreement: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Divider()
            Toggle("I have read and agree to the Terms of Use", isOn: $agreed)
                .font(.body)
            if let errorMessage {
                Banner(style: .error, message: errorMessage)
            }
            PrimaryButton(title: "I agree", isLoading: isSubmitting, action: onAccept)
                .disabled(!agreed)
                .opacity(agreed ? 1 : 0.5)
            Button("Decline and sign out", role: .destructive, action: onDismiss)
                .frame(minHeight: Theme.Size.minTapTarget)
        }
    }

    private func markdown(_ text: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }
}

#Preview("Gate") {
    TermsOfUseSheet(requiresAcceptance: true, onDismiss: {})
}

#Preview("Read-only, AX5") {
    TermsOfUseSheet(onDismiss: {}).dynamicTypeSize(.accessibility5)
}
