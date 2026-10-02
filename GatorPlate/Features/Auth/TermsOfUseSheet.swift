import SwiftUI

/// Terms of Use. `requiresAcceptance` adds the agree checkbox, "I agree" and "Decline" controls
/// (driven by the environment's `AuthViewModel`); otherwise it is read-only with a Done button.
struct TermsOfUseSheet: View {
    let requiresAcceptance: Bool
    /// Injectable for previews and tests; defaults to the bundled file.
    var document: TermsDocument? = TermsDocument.loadBundled()

    @Environment(AuthViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                    Text("Version \(AppConfig.termsVersion)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let document {
                        if let keyPoints = document.keyPoints {
                            keyPointsCard(keyPoints)
                        }
                        ForEach(document.fullText) { section in
                            sectionView(section)
                        }
                    } else {
                        Banner(kind: .error, message: "The Terms of Use could not be loaded. Please restart the app.")
                    }
                }
                .padding(Theme.Spacing.l)
            }
            .navigationTitle("Terms of Use")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !requiresAcceptance {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if requiresAcceptance { acceptanceBar }
            }
        }
    }

    private func keyPointsCard(_ section: TermsDocument.Section) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Label(section.title, systemImage: "exclamationmark.circle.fill")
                .font(.headline)
                .foregroundStyle(Color.brandPurple)
                .accessibilityAddTraits(.isHeader)
            ForEach(Array(section.blocks.enumerated()), id: \.offset) { _, block in
                blockView(block)
            }
        }
        .padding(Theme.Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.surfaceSecondary, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
    }

    private func sectionView(_ section: TermsDocument.Section) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text(section.title)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            ForEach(Array(section.blocks.enumerated()), id: \.offset) { _, block in
                blockView(block)
            }
        }
    }

    @ViewBuilder
    private func blockView(_ block: TermsDocument.Block) -> some View {
        switch block {
        case .paragraph(let text):
            Text(Self.styled(text)).font(.body)
        case .bullet(let text):
            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.s) {
                Text("•").accessibilityHidden(true)
                Text(Self.styled(text))
            }
            .font(.body)
        case .numbered(let number, let text):
            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.s) {
                Text("\(number).")
                Text(Self.styled(text))
            }
            .font(.body)
        }
    }

    private var acceptanceBar: some View {
        VStack(spacing: Theme.Spacing.m) {
            if let message = viewModel.termsError {
                Banner(kind: .error, message: message)
            }

            Button {
                viewModel.hasAgreedToTerms.toggle()
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.m) {
                    Image(systemName: viewModel.hasAgreedToTerms ? "checkmark.square.fill" : "square")
                        .font(.title3)
                        .foregroundStyle(Color.brandPurple)
                        .accessibilityHidden(true)
                    Text("I have read and agree to the Terms of Use")
                        .font(.body)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(minHeight: Theme.minTapTarget)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(.isToggle)
            .accessibilityValue(viewModel.hasAgreedToTerms ? "Checked" : "Unchecked")

            PrimaryButton(title: "I agree", isLoading: viewModel.isAcceptingTerms) {
                Task { await viewModel.acceptTerms() }
            }
            .disabled(!viewModel.hasAgreedToTerms || document == nil)
            .opacity(viewModel.hasAgreedToTerms && document != nil ? 1 : 0.5)
            .accessibilityHint(viewModel.hasAgreedToTerms ? "" : "Check the box above first")

            Button("Decline and sign out", role: .cancel) {
                Task { await viewModel.declineTerms() }
            }
            .frame(minHeight: Theme.minTapTarget)
            .tint(Color.brandPurple)
        }
        .padding(Theme.Spacing.l)
        .background(Color.surface)
    }

    /// Inline `**bold**` only; falls back to plain text if parsing fails.
    private static func styled(_ text: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }
}

#Preview("Accept") {
    Color.clear.sheet(isPresented: .constant(true)) {
        TermsOfUseSheet(requiresAcceptance: true)
    }
    .environment(AuthViewModel(auth: MockAuthService(), initialState: .signedOut))
    .environment(\.appEnvironment, .mock)
}

#Preview("Review, AX3") {
    TermsOfUseSheet(requiresAcceptance: false)
        .environment(AuthViewModel(auth: MockAuthService(), initialState: .signedOut))
        .environment(\.appEnvironment, .mock)
        .dynamicTypeSize(.accessibility3)
}
