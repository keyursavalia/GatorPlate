import SwiftUI

/// Items editor: rename, diet picker, remove, add. Calories are AI estimates and read-only.
struct ReviewItemsSection: View {
    @Bindable var viewModel: ReviewViewModel

    var body: some View {
        Section {
            ForEach(viewModel.draft.items) { item in
                itemRow(item)
            }
            .onDelete { offsets in
                for id in offsets.map({ viewModel.draft.items[$0].id }) { viewModel.removeItem(id) }
            }
            if viewModel.draft.items.count < AppConfig.postMaxItems {
                Button {
                    viewModel.addItem()
                } label: {
                    Label("Add item", systemImage: "plus.circle.fill")
                }
            }
            HStack(spacing: Theme.Spacing.sm) {
                Text("Overall").font(.subheadline.weight(.semibold))
                DietaryBadge(dietary: viewModel.draft.overallDietary, isEstimate: viewModel.aiBaseline != nil)
            }
            .accessibilityElement(children: .combine)
            Toggle("Show calorie estimates", isOn: $viewModel.showCalories)
        } header: {
            ReviewSectionHeader(title: "Items", isAIValue: viewModel.isAIValue(.items))
        } footer: {
            if let issue = viewModel.warning(for: .items) { ReviewIssueText(issue: issue) }
        }
    }

    private func itemRow(_ item: PostDraft.Item) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                TextField("Food item, e.g. Veggie pizza", text: nameBinding(for: item.id))
                    .textInputAutocapitalization(.sentences)
                    .accessibilityLabel("Food item name")
                if viewModel.draft.items.count > 1 {
                    Button {
                        viewModel.removeItem(item.id)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(Theme.Palette.danger)
                            .frame(minWidth: Theme.Size.minTapTarget, minHeight: Theme.Size.minTapTarget)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Remove \(item.name.isEmpty ? "item" : item.name)")
                }
            }
            Picker("Diet", selection: dietaryBinding(for: item.id)) {
                ForEach(DietaryClass.itemChoices, id: \.self) { dietary in
                    Label(dietary.label, systemImage: dietary.icon).tag(dietary)
                }
            }
            .pickerStyle(.menu)
            if viewModel.showCalories, let calories = item.calories {
                Label("\(calories.low)–\(calories.high) cal · estimate", systemImage: "flame")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("\(calories.low) to \(calories.high) calories per serving, estimate")
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
    }

    private func nameBinding(for id: UUID) -> Binding<String> {
        Binding(
            get: { viewModel.draft.items.first { $0.id == id }?.name ?? "" },
            set: { viewModel.setItemName($0, for: id) })
    }

    private func dietaryBinding(for id: UUID) -> Binding<DietaryClass> {
        Binding(
            get: { viewModel.draft.items.first { $0.id == id }?.dietary ?? .unknown },
            set: { newValue in
                guard let index = viewModel.draft.items.firstIndex(where: { $0.id == id }) else { return }
                viewModel.draft.items[index].dietary = newValue
            })
    }
}

extension DietaryClass {
    /// Per-item choices; "mixed" only applies to a whole post.
    static let itemChoices: [DietaryClass] = [.vegan, .vegetarian, .nonVegetarian, .unknown]
}

/// Section title with the AI badge while the value is still the AI's.
struct ReviewSectionHeader: View {
    let title: String
    var isAIValue = false

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Text(title)
            if isAIValue { AIBadge() }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// Inline validation message: blocking issues in red, warnings in orange, always with an icon.
struct ReviewIssueText: View {
    let issue: PostDraftValidator.Issue

    var body: some View {
        Label(issue.message, systemImage: issue.isBlocking ? "exclamationmark.circle.fill" : "exclamationmark.triangle.fill")
            .font(.footnote)
            .foregroundStyle(issue.isBlocking ? Theme.Palette.danger : Theme.Palette.warning)
            .accessibilityLabel("\(issue.isBlocking ? "Required" : "Tip"): \(issue.message)")
    }
}
