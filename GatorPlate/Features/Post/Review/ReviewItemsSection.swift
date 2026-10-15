import SwiftUI

/// Items editor inside "What's there": name, a diet Menu pill and a ⋯ menu to remove; Add item; the overall diet.
/// Calories are AI estimates, shown in "Allergens & safety".
struct ReviewItemsSection: View {
    @Bindable var viewModel: ReviewViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.sm) {
                Text("Items").font(.subheadline.weight(.semibold))
                if viewModel.isAIValue(.items) { AIBadge() }
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            ForEach(viewModel.draft.items) { item in
                itemRow(item)
            }
            if viewModel.draft.items.count < AppConfig.postMaxItems {
                Button("Add item", systemImage: "plus.circle.fill") { viewModel.addItem() }
                    .font(.subheadline)
                    .frame(minHeight: Theme.Size.minTapTarget)
            }
            HStack(spacing: Theme.Spacing.sm) {
                Text("Overall").font(.subheadline).foregroundStyle(.secondary)
                DietaryBadge(dietary: viewModel.draft.overallDietary, isEstimate: viewModel.aiBaseline != nil)
            }
            .accessibilityElement(children: .combine)
            if let issue = viewModel.warning(for: .items) { ReviewIssueText(issue: issue) }
        }
    }

    private func itemRow(_ item: PostDraft.Item) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Theme.Spacing.sm) { itemContent(item) }
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) { itemContent(item) }
        }
        .padding(.vertical, Theme.Spacing.xs)
    }

    @ViewBuilder
    private func itemContent(_ item: PostDraft.Item) -> some View {
        TextField("Food item, e.g. Veggie pizza", text: nameBinding(for: item.id))
            .textInputAutocapitalization(.sentences)
            .padding(Theme.Spacing.md)
            .background(.background, in: .rect(cornerRadius: Theme.Radius.field))
            .accessibilityLabel("Food item name")
        HStack(spacing: Theme.Spacing.xs) {
            Menu {
                Picker("Diet", selection: dietaryBinding(for: item.id)) {
                    ForEach(DietaryClass.itemChoices, id: \.self) { dietary in
                        Label(dietary.label, systemImage: dietary.icon).tag(dietary)
                    }
                }
            } label: {
                HStack(spacing: Theme.Spacing.xs) {
                    Label(item.dietary.label, systemImage: item.dietary.icon)
                    Image(systemName: "chevron.up.chevron.down").font(.caption2)
                }
                .font(.subheadline)
                .padding(.horizontal, Theme.Spacing.md)
                .frame(minHeight: Theme.Size.minTapTarget)
                .background(Theme.Palette.brandPurple.opacity(0.12), in: .capsule)
            }
            .accessibilityLabel("Diet for \(item.name.isEmpty ? "item" : item.name): \(item.dietary.label)")
            if viewModel.draft.items.count > 1 {
                Menu {
                    Button("Remove item", systemImage: "trash", role: .destructive) { viewModel.removeItem(item.id) }
                } label: {
                    Image(systemName: "ellipsis")
                        .frame(minWidth: Theme.Size.minTapTarget, minHeight: Theme.Size.minTapTarget)
                }
                .accessibilityLabel("More for \(item.name.isEmpty ? "item" : item.name)")
            }
        }
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
