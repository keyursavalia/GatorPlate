import SwiftUI

/// Items list: rename, dietary class, add and remove. Calories show only when the poster leaves them on.
struct ReviewItemsSection: View {
    let viewModel: ReviewViewModel
    let showCalories: Bool

    var body: some View {
        Section {
            ForEach(viewModel.draft.items) { item in
                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    HStack {
                        TextField("Food item", text: Binding(
                            get: { item.name },
                            set: { viewModel.renameItem(id: item.id, to: $0) }
                        ))
                        .accessibilityLabel("Food item name")
                        Button(role: .destructive) {
                            viewModel.removeItem(id: item.id)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .frame(minWidth: Theme.minTapTarget, minHeight: Theme.minTapTarget)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.danger)
                        .accessibilityLabel("Remove \(item.name.isEmpty ? "item" : item.name)")
                    }
                    Picker("Dietary", selection: Binding(
                        get: { item.dietary },
                        set: { viewModel.setDietary($0, forItem: item.id) }
                    )) {
                        ForEach(Self.editableClasses, id: \.self) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.menu)
                    .accessibilityLabel("Dietary class for \(item.name.isEmpty ? "item" : item.name)")
                    if showCalories, let calories = item.calories {
                        Text("About \(calories.low) to \(calories.high) cal per serving (estimate)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            if viewModel.draft.items.count < AppConfig.maxFoodItems {
                Button {
                    viewModel.addItem()
                } label: {
                    Label("Add item", systemImage: "plus.circle")
                        .frame(minHeight: Theme.minTapTarget, alignment: .leading)
                }
            }
            ForEach(viewModel.issues(for: .items), id: \.message) { IssueText(issue: $0) }
        } header: {
            ReviewSectionHeader(title: "Items", showsAI: viewModel.showsAIBadge(.items))
        } footer: {
            Text("Overall: \(viewModel.draft.overallDietary.label). Dietary labels are estimates. If unsure, leave Unknown.")
        }
    }

    /// `mixed` is computed from the items, never picked per item.
    private static let editableClasses: [DietaryClass] = [.vegan, .vegetarian, .nonVegetarian, .unknown]
}

/// Allergen toggles. "May contain" wording only: the app never says a food is free of an allergen.
struct ReviewAllergensSection: View {
    let viewModel: ReviewViewModel

    var body: some View {
        Section {
            FlowLayout {
                ForEach(Allergen.allCases, id: \.self) { allergen in
                    let selected = viewModel.draft.allergens.contains(allergen)
                    Button {
                        viewModel.toggleAllergen(allergen)
                    } label: {
                        Label(allergen.label, systemImage: selected ? "checkmark.circle.fill" : "circle")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, Theme.Spacing.m)
                            .frame(minHeight: Theme.minTapTarget)
                            .foregroundStyle(selected ? Color.warning : Color.secondary)
                            .background(
                                (selected ? Color.warning.opacity(0.15) : Color.surfaceSecondary), in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("May contain \(allergen.label)")
                    .accessibilityValue(selected ? "Selected" : "Not selected")
                    .accessibilityAddTraits(.isToggle)
                }
            }
            if viewModel.draft.allergensUnverified && viewModel.draft.allergens.isEmpty {
                Label("Allergen info unverified. Posts will say so.", systemImage: "questionmark.circle")
                    .font(.subheadline.weight(.semibold))
            }
        } header: {
            ReviewSectionHeader(title: "May contain", showsAI: viewModel.showsAIBadge(.allergens))
        } footer: {
            Text("Select every allergen the food may contain. Always confirm with the host.")
        }
    }
}

/// Food safety notes, one per row.
struct ReviewCautionsSection: View {
    let viewModel: ReviewViewModel

    var body: some View {
        Section {
            ForEach(Array(viewModel.draft.cautions.enumerated()), id: \.offset) { index, caution in
                HStack {
                    TextField("Food safety note", text: Binding(
                        get: { caution },
                        set: { value in
                            var updated = viewModel.draft.cautions
                            guard updated.indices.contains(index) else { return }
                            updated[index] = String(value.prefix(AppConfig.maxCautionLength))
                            viewModel.setCautions(updated)
                        }
                    ), axis: .vertical)
                    Button(role: .destructive) {
                        viewModel.removeCaution(at: index)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .frame(minWidth: Theme.minTapTarget, minHeight: Theme.minTapTarget)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.danger)
                    .accessibilityLabel("Remove note \(index + 1)")
                }
            }
            if viewModel.draft.cautions.count < AppConfig.maxCautions {
                Button {
                    viewModel.addCaution()
                } label: {
                    Label("Add food safety note", systemImage: "plus.circle")
                        .frame(minHeight: Theme.minTapTarget, alignment: .leading)
                }
            }
            ForEach(viewModel.issues(for: .cautions), id: \.message) { IssueText(issue: $0) }
        } header: {
            ReviewSectionHeader(title: "Food safety notes", showsAI: viewModel.showsAIBadge(.cautions) && !viewModel.draft.cautions.isEmpty)
        }
    }
}

struct ReviewSectionHeader: View {
    let title: String
    var showsAI = false

    var body: some View {
        HStack {
            Text(title)
            if showsAI { AIBadge() }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// Inline, specific error or hint under a field. Warnings are orange with an icon, errors red with an icon.
struct IssueText: View {
    let issue: PostValidation.Issue

    var body: some View {
        Label(
            issue.message,
            systemImage: issue.isBlocking ? "xmark.octagon.fill" : "exclamationmark.triangle.fill"
        )
        .font(.footnote)
        .foregroundStyle(issue.isBlocking ? Color.danger : Color.warning)
        .accessibilityLabel("\(issue.isBlocking ? "Error" : "Tip"): \(issue.message)")
    }
}
