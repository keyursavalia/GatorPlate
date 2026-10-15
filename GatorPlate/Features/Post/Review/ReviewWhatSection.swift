import SwiftUI

/// Fields the keyboard toolbar moves through, in order.
enum ReviewFocus: Hashable {
    case title, description, room
}

/// "What's there": the title (auto-title preview line, or the user's own), items with a diet pill, the
/// description with its counter, and servings.
struct ReviewWhatSection: View {
    @Bindable var viewModel: ReviewViewModel
    var focus: FocusState<ReviewFocus?>.Binding
    var highlighted: PostDraftValidator.Field?

    @State private var isWritingTitle = false

    var body: some View {
        SectionCard(title: "What's there", systemImage: "fork.knife") {
            if isAnyAIValue { AIBadge() }
        } content: {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                title.id(PostDraftValidator.Field.title)
                Divider()
                ReviewItemsSection(viewModel: viewModel).id(PostDraftValidator.Field.items)
                Divider()
                description.id(PostDraftValidator.Field.description)
                Divider()
                servings.id(PostDraftValidator.Field.servings)
            }
        }
        .reviewHighlight(highlighted.map { [.title, .items, .description, .servings].contains($0) } ?? false)
    }

    private var isAnyAIValue: Bool {
        viewModel.isAIValue(.title) || viewModel.isAIValue(.items) || viewModel.isAIValue(.description)
    }

    // MARK: Title

    @ViewBuilder
    private var title: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            fieldLabel("Title", isAI: viewModel.isAIValue(.title))
            if viewModel.draft.titleIsCustom || isWritingTitle {
                TextField("FREE: food - place - until time", text: $viewModel.title, axis: .vertical)
                    .lineLimit(1...3)
                    .focused(focus, equals: .title)
                    .submitLabel(.next)
                    .padding(Theme.Spacing.md)
                    .background(.background, in: .rect(cornerRadius: Theme.Radius.field))
                    .accessibilityLabel("Title")
                if viewModel.draft.titleIsCustom {
                    Button("Use suggested title") {
                        viewModel.useSuggestedTitle()
                        isWritingTitle = false
                    }
                    .font(.subheadline)
                    .frame(minHeight: Theme.Size.minTapTarget)
                    .accessibilityHint("Replaces your title with \(viewModel.suggestedTitle)")
                }
            } else {
                HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                    Text(viewModel.draft.title)
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button("Write your own title", systemImage: "pencil") {
                        isWritingTitle = true
                        focus.wrappedValue = .title
                    }
                    .labelStyle(.iconOnly)
                    .frame(minWidth: Theme.Size.minTapTarget, minHeight: Theme.Size.minTapTarget)
                }
                Text("Follows the food, place and time until you write your own.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if let issue = viewModel.warning(for: .title) { ReviewIssueText(issue: issue) }
        }
    }

    // MARK: Description

    private var description: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                fieldLabel("Description", isAI: viewModel.isAIValue(.description))
                Spacer()
                Text("\(viewModel.draft.description.count)/\(AppConfig.postDescriptionMaxLength)")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(viewModel.warning(for: .description) == nil ? Color.secondary : Theme.Palette.warning)
                    .accessibilityLabel("\(viewModel.draft.description.count) of \(AppConfig.postDescriptionMaxLength) characters")
            }
            TextField("What it is, how much, anything to know", text: $viewModel.description, axis: .vertical)
                .lineLimit(3...6)
                .focused(focus, equals: .description)
                .padding(Theme.Spacing.md)
                .background(.background, in: .rect(cornerRadius: Theme.Radius.field))
                .accessibilityLabel("Description")
            if let issue = viewModel.warning(for: .description) { ReviewIssueText(issue: issue) }
        }
    }

    // MARK: Servings

    private var servings: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Theme.Spacing.md) { servingsContent }
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) { servingsContent }
        }
    }

    @ViewBuilder
    private var servingsContent: some View {
        fieldLabel("Servings", isAI: viewModel.isAIValue(.servings) && viewModel.draft.estimatedServings != nil)
        Spacer(minLength: 0)
        if let servings = viewModel.draft.estimatedServings {
            Stepper(value: servingsBinding(default: servings), in: AppConfig.postServingsRange, step: 5) {
                Text("~\(servings)").font(.headline.monospacedDigit())
            }
            .fixedSize()
            .accessibilityLabel("About \(servings) servings")
            Button("Not sure") { viewModel.draft.estimatedServings = nil }
                .font(.subheadline)
                .frame(minHeight: Theme.Size.minTapTarget)
        } else {
            Button("Add an estimate", systemImage: "plus.circle.fill") { viewModel.draft.estimatedServings = 10 }
                .font(.subheadline)
                .frame(minHeight: Theme.Size.minTapTarget)
        }
    }

    private func servingsBinding(default value: Int) -> Binding<Int> {
        Binding(get: { viewModel.draft.estimatedServings ?? value },
                set: { viewModel.draft.estimatedServings = $0 })
    }

    private func fieldLabel(_ text: String, isAI: Bool) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            Text(text).font(.subheadline.weight(.semibold))
            if isAI { AIBadge() }
        }
        .accessibilityElement(children: .combine)
    }
}

extension View {
    /// A brief outline when "N things left" scrolls to this section.
    func reviewHighlight(_ isOn: Bool) -> some View {
        overlay {
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .strokeBorder(Theme.Palette.danger, lineWidth: isOn ? 2 : 0)
                .allowsHitTesting(false)
        }
    }
}
