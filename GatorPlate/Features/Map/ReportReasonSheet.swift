import SwiftUI

/// Report a post: four large choices (Unsafe to eat / Offensive or inappropriate / Spam or misleading / Selling or
/// trading). Unsafe opens a required "What makes it unsafe?" field that an AI checks before the post is removed; the
/// others take an optional note. Guests see a "Create a free account" prompt instead (reports need a verified account). The poster is
/// never told who reported.
struct ReportReasonSheet: View {
    let post: FoodPost
    let viewModel: MapViewModel

    @State private var category: ReportCategory?
    @State private var reason = ""
    @FocusState private var isReasonFocused: Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.canReport {
                    form
                } else {
                    guestPrompt
                }
            }
            .navigationTitle("Report post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                if viewModel.canReport {
                    ToolbarItem(placement: .confirmationAction) {
                        if viewModel.reportStatus == .working {
                            ProgressView()
                        } else {
                            Button("Send", action: send)
                                .disabled(!canSend)
                        }
                    }
                }
            }
        }
        .presentationDetents(viewModel.canReport ? [.large] : [.medium])
    }

    // MARK: Form

    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                Text("What's wrong with this post?")
                    .font(.title3.bold())
                    .accessibilityAddTraits(.isHeader)

                VStack(spacing: Theme.Spacing.sm) {
                    ForEach(ReportCategory.allCases) { option in
                        CategoryChoice(category: option, isSelected: category == option) {
                            withAnimation(reduceMotion ? nil : .snappy) { category = option }
                            if option.requiresReason { isReasonFocused = true }
                        }
                    }
                }

                if let category {
                    reasonField(for: category)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                if case .failed(let message) = viewModel.reportStatus {
                    Label(message, systemImage: "exclamationmark.triangle")
                        .font(.subheadline)
                        .foregroundStyle(Theme.Palette.danger)
                }

                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Label("Reports are private. The poster isn't told who reported.", systemImage: "lock.fill")
                    Label("Offensive reports are reviewed by a person within 24 hours.", systemImage: "person.badge.shield.checkmark")
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
            .padding(Theme.Spacing.lg)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func reasonField(for category: ReportCategory) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(category.requiresReason ? "What makes it unsafe?"
                 : category == .offensive ? "What's wrong? (optional)" : "Anything else? (optional)")
                .font(.headline)
            TextField(category.requiresReason ? "e.g. The chicken is pink inside and has been out since noon."
                                              : "Add a detail",
                      text: $reason, axis: .vertical)
                .lineLimit(3...6)
                .focused($isReasonFocused)
                .padding(Theme.Spacing.md)
                .background(.background.secondary, in: .rect(cornerRadius: Theme.Radius.field))
                .onChange(of: reason) { _, new in
                    if new.count > AppConfig.reportReasonMaxLength {
                        reason = String(new.prefix(AppConfig.reportReasonMaxLength))
                    }
                }
                .accessibilityLabel(category.requiresReason ? "What makes it unsafe" : "Optional detail")
            HStack(alignment: .firstTextBaseline) {
                if category.requiresReason {
                    Label("Your reason and the post's photo are sent to Google's Gemini AI to check the report.",
                          systemImage: "sparkles")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: Theme.Spacing.sm)
                Text("\(trimmedReason.count)/\(AppConfig.reportReasonMaxLength)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(reasonTooShort ? AnyShapeStyle(Theme.Palette.warning) : AnyShapeStyle(.tertiary))
                    .accessibilityLabel(reasonTooShort
                        ? "At least \(AppConfig.reportReasonMinLength) characters needed"
                        : "\(trimmedReason.count) of \(AppConfig.reportReasonMaxLength) characters")
            }
        }
    }

    // MARK: Guests

    private var guestPrompt: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: "flag.fill")
                .font(.largeTitle)
                .foregroundStyle(Theme.Palette.brandPurple)
                .accessibilityHidden(true)
            VStack(spacing: Theme.Spacing.sm) {
                Text("Create a free account to report")
                    .font(.title3.bold())
                Text("Reports can remove posts, so each one needs a verified account. It takes a minute.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
            PrimaryButton(title: "Create free account") {
                viewModel.requestAccountToReport()
            }
        }
        .padding(Theme.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Sending

    private var trimmedReason: String {
        reason.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var reasonTooShort: Bool {
        category?.requiresReason == true && trimmedReason.count < AppConfig.reportReasonMinLength
    }

    private var canSend: Bool {
        category != nil && !reasonTooShort
    }

    private func send() {
        guard let category else { return }
        Task {
            if await viewModel.report(post, category: category, reason: trimmedReason) {
                dismiss()
            }
        }
    }
}

/// One report choice: a tinted icon, the label and a one-line explainer, with a check when selected.
private struct CategoryChoice: View {
    let category: ReportCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: category.systemImage)
                    .font(.title3)
                    .foregroundStyle(tint)
                    .frame(width: 40, height: 40)
                    .background(tint.opacity(0.15), in: .rect(cornerRadius: 10))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(category.label)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(category.explainer)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? AnyShapeStyle(Theme.Palette.accent) : AnyShapeStyle(.tertiary))
                    .accessibilityHidden(true)
            }
            .padding(Theme.Spacing.md)
            .background(.background.secondary, in: .rect(cornerRadius: Theme.Radius.field))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.field)
                    .strokeBorder(isSelected ? Theme.Palette.accent : .clear, lineWidth: 2)
            }
            .contentShape(.rect(cornerRadius: Theme.Radius.field))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var tint: Color {
        switch category {
        case .unsafe, .offensive: Theme.Palette.danger
        case .misleading: Theme.Palette.warning
        case .trading: Theme.Palette.brandPurple
        }
    }
}
