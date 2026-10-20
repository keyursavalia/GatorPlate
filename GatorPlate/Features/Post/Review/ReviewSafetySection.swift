import SwiftUI

/// "May contain" as a checklist of the nine allergens, "Heads up" notes, and the calorie estimate (shown when
/// Settings > Show calorie estimates is on; always saved).
struct ReviewSafetySection: View {
    @Bindable var viewModel: ReviewViewModel
    var highlighted: PostDraftValidator.Field?

    var body: some View {
        Section {
            ForEach(Allergen.allCases, id: \.self) { allergen in
                CheckRow(title: allergen.displayName, isSelected: viewModel.draft.allergens.contains(allergen)) {
                    viewModel.toggleAllergen(allergen)
                }
                .accessibilityValue(viewModel.draft.allergens.contains(allergen) ? "May contain" : "Not listed")
            }
        } header: {
            ReviewSectionHeader(title: "May contain", isAI: viewModel.allergensMatchAI)
        } footer: {
            if viewModel.draft.allergens.isEmpty {
                Label("None checked: students see allergens as not listed.", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(Theme.Palette.warning)
            } else {
                Text("Never a guarantee. Students confirm with the host.")
            }
        }

        Section {
            ForEach(viewModel.draft.cautions) { caution in
                TextField("e.g. Contains raw onion", text: cautionBinding(for: caution.id), axis: .vertical)
                    .accessibilityLabel("Caution note")
                    .listRowBackground(rowHighlight(highlighted == .cautions))
                    .swipeActions {
                        Button("Remove", systemImage: "trash", role: .destructive) { viewModel.removeCaution(caution.id) }
                    }
            }
            if let issue = viewModel.warning(for: .cautions) {
                ReviewIssueText(issue: issue)
            }
            if viewModel.draft.cautions.count < AppConfig.postMaxCautions {
                Button("Add a note", systemImage: "plus") { viewModel.addCaution() }
                    .foregroundStyle(Theme.Palette.accent)
            }
        } header: {
            ReviewSectionHeader(title: "Heads up",
                                isAI: viewModel.isAIValue(.cautions) && !viewModel.draft.cautions.isEmpty)
        } footer: {
            Text("Anything students should know, e.g. spicy or contains raw onion. Optional.")
        }
        .id(PostDraftValidator.Field.cautions)

        if viewModel.showCalories, !caloriesItems.isEmpty {
            Section {
                ForEach(caloriesItems) { item in
                    if let range = item.calories {
                        ListRow(title: item.name.isEmpty ? "Item" : item.name, systemImage: "flame",
                                value: "\(range.low)–\(range.high) kcal")
                            .accessibilityLabel("\(item.name): \(range.low) to \(range.high) calories per serving, estimate")
                    }
                }
            } header: {
                ReviewSectionHeader(title: "Calories (estimate)", isAI: true)
            } footer: {
                Text("Per serving. Hide these in Settings > Show calorie estimates.")
            }
        }
    }

    private var caloriesItems: [PostDraft.Item] {
        viewModel.draft.items.filter { $0.calories != nil }
    }

    private func cautionBinding(for id: UUID) -> Binding<String> {
        Binding(get: { viewModel.draft.cautions.first { $0.id == id }?.text ?? "" },
                set: { viewModel.setCautionText($0, for: id) })
    }
}
