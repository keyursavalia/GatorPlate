import SwiftUI

/// Item rows inside "What's there": the diet icon, the name, and a diet menu on the right; swipe to remove.
/// Then Add item and the overall diet. Calories are AI estimates, shown in their own section.
struct ReviewItemsSection: View {
    @Bindable var viewModel: ReviewViewModel
    var highlighted: PostDraftValidator.Field?

    @ScaledMetric(relativeTo: .body) private var iconWidth: CGFloat = 28

    var body: some View {
        ForEach(viewModel.draft.items) { item in
            itemRow(item)
                .listRowBackground(rowHighlight(highlighted == .items))
                .swipeActions {
                    if viewModel.draft.items.count > 1 {
                        Button("Remove", systemImage: "trash", role: .destructive) { viewModel.removeItem(item.id) }
                    }
                }
        }
        if viewModel.draft.items.count < AppConfig.postMaxItems {
            Button("Add item", systemImage: "plus") { viewModel.addItem() }
                .foregroundStyle(Theme.Palette.brandPurple)
        }
        ListRow(title: "Overall", systemImage: viewModel.draft.overallDietary.icon,
                value: viewModel.aiBaseline != nil ? viewModel.draft.overallDietary.estimateLabel
                                                   : viewModel.draft.overallDietary.label,
                iconTint: viewModel.draft.overallDietary.tint)
            // "N things left" scrolls here for a missing item name.
            .id(PostDraftValidator.Field.items)
    }

    private func itemRow(_ item: PostDraft.Item) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: item.dietary.icon)
                .foregroundStyle(item.dietary.tint)
                .frame(width: iconWidth)
                .accessibilityHidden(true)
            TextField("Food item, e.g. Veggie pizza", text: nameBinding(for: item.id))
                .textInputAutocapitalization(.sentences)
                .accessibilityLabel("Food item name")
            Menu {
                Picker("Diet", selection: dietaryBinding(for: item.id)) {
                    ForEach(DietaryClass.itemChoices, id: \.self) { dietary in
                        Label(dietary.label, systemImage: dietary.icon).tag(dietary)
                    }
                }
            } label: {
                HStack(spacing: 2) {
                    Text(item.dietary.label)
                    Image(systemName: "chevron.up.chevron.down").font(.caption2)
                }
                .font(.subheadline)
                .foregroundStyle(Theme.Palette.brandPurple)
                .fixedSize()
            }
            .accessibilityLabel("Diet for \(item.name.isEmpty ? "item" : item.name): \(item.dietary.label)")
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
