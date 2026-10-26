import SwiftUI

/// Title (follows the food, place and time until the poster writes their own), what's there (items, overall
/// diet, servings) and the description.
struct ReviewWhatSection: View {
    @Bindable var viewModel: ReviewViewModel
    var focus: FocusState<ReviewFocus?>.Binding
    var highlighted: PostDraftValidator.Field?

    @State private var isWritingTitle = false

    var body: some View {
        Section {
            titleRow
                .listRowBackground(rowHighlight(highlighted == .title))
                .id(PostDraftValidator.Field.title)
        } header: {
            ReviewSectionHeader(title: "Title", isAI: viewModel.isAIValue(.title))
        } footer: {
            titleFooter
        }

        Section {
            ReviewItemsSection(viewModel: viewModel, highlighted: highlighted)
            servingsRow
                .listRowBackground(rowHighlight(highlighted == .servings))
                .id(PostDraftValidator.Field.servings)
        } header: {
            ReviewSectionHeader(title: "What's there", isAI: viewModel.isAIValue(.items))
        } footer: {
            if let issue = viewModel.warning(for: .items) { ReviewIssueText(issue: issue) }
        }

        Section {
            TextField("What it is, how much, anything to know", text: $viewModel.description, axis: .vertical)
                .lineLimit(2...6)
                .focused(focus, equals: .description)
                .accessibilityLabel("Description")
                .listRowBackground(rowHighlight(highlighted == .description))
                .id(PostDraftValidator.Field.description)
        } header: {
            ReviewSectionHeader(title: "Description", isAI: viewModel.isAIValue(.description))
        } footer: {
            HStack(alignment: .firstTextBaseline) {
                if let issue = viewModel.warning(for: .description) {
                    ReviewIssueText(issue: issue)
                }
                Spacer(minLength: Theme.Spacing.sm)
                Text("\(viewModel.draft.description.count)/\(AppConfig.postDescriptionMaxLength)")
                    .monospacedDigit()
                    .accessibilityLabel("\(viewModel.draft.description.count) of \(AppConfig.postDescriptionMaxLength) characters")
            }
        }
    }

    // MARK: Title

    @ViewBuilder
    private var titleRow: some View {
        if viewModel.draft.titleIsCustom || isWritingTitle {
            TextField("Food - place - until time", text: $viewModel.title, axis: .vertical)
                .lineLimit(1...3)
                .font(.body.weight(.semibold))
                .focused(focus, equals: .title)
                .submitLabel(.next)
                .accessibilityLabel("Title")
        } else {
            Button {
                isWritingTitle = true
                focus.wrappedValue = .title
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
                    Text(viewModel.draft.title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "pencil")
                        .foregroundStyle(Theme.Palette.accent)
                        .accessibilityHidden(true)
                }
                .contentShape(.rect)
            }
            .accessibilityLabel("Title: \(viewModel.draft.title)")
            .accessibilityHint("Write your own title")
        }
    }

    @ViewBuilder
    private var titleFooter: some View {
        if let issue = viewModel.warning(for: .title) {
            ReviewIssueText(issue: issue)
        } else if viewModel.draft.titleIsCustom {
            Button("Use suggested title") {
                viewModel.useSuggestedTitle()
                isWritingTitle = false
                focus.wrappedValue = nil
            }
            .font(.footnote.weight(.semibold))
            .accessibilityHint("Replaces your title with \(viewModel.suggestedTitle)")
        } else {
            Text("Updates with the food, place and time until you edit it.")
        }
    }

    // MARK: Servings

    @ViewBuilder
    private var servingsRow: some View {
        if let servings = viewModel.draft.estimatedServings {
            Stepper(value: servingsBinding(default: servings), in: AppConfig.postServingsRange) {
                ListRow(title: "Servings", systemImage: "person.2", value: "~\(servings)")
            }
            .accessibilityLabel("About \(servings) servings")
            .swipeActions {
                Button("Not sure") { viewModel.draft.estimatedServings = nil }
            }
            .accessibilityAction(named: "Not sure") { viewModel.draft.estimatedServings = nil }
        } else {
            Button {
                viewModel.draft.estimatedServings = 10
            } label: {
                ListRow(title: "Servings", systemImage: "person.2", value: "Add estimate")
            }
        }
    }

    private func servingsBinding(default value: Int) -> Binding<Int> {
        Binding(get: { viewModel.draft.estimatedServings ?? value },
                set: { viewModel.draft.estimatedServings = $0 })
    }
}
