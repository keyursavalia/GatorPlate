import SwiftUI

/// "Allergens & safety": "May contain" chips for all nine allergens, cautions, and the calorie estimate
/// (hideable here; Settings sets the default).
struct ReviewSafetySection: View {
    @Bindable var viewModel: ReviewViewModel

    var body: some View {
        SectionCard(title: "Allergens & safety", systemImage: "exclamationmark.shield") {
            if viewModel.allergensMatchAI { AIBadge() }
        } content: {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                allergens
                Divider()
                cautions
                if hasCalories {
                    Divider()
                    calories
                }
            }
        }
    }

    // MARK: Allergens

    private var allergens: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("May contain").font(.subheadline.weight(.semibold))
            FlowLayout {
                ForEach(Allergen.allCases, id: \.self) { allergen in
                    ToggleChip(title: allergen.displayName, systemImage: "exclamationmark.triangle",
                               isSelected: viewModel.draft.allergens.contains(allergen),
                               tint: Theme.Palette.warning) {
                        viewModel.toggleAllergen(allergen)
                    }
                    .accessibilityValue(viewModel.draft.allergens.contains(allergen) ? "May contain" : "Not listed")
                }
            }
            if viewModel.draft.allergens.isEmpty {
                Label("Allergen info unverified, ask the host.", systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(Theme.Palette.warning)
            }
            Text("Allergens are never guaranteed. Students should always confirm with the host.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Cautions

    private var cautions: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.sm) {
                Text("Cautions").font(.subheadline.weight(.semibold))
                if viewModel.isAIValue(.cautions), !viewModel.draft.cautions.isEmpty { AIBadge() }
            }
            .accessibilityElement(children: .combine)
            ForEach(viewModel.draft.cautions) { caution in
                HStack(spacing: Theme.Spacing.sm) {
                    TextField("e.g. Contains raw onion", text: cautionBinding(for: caution.id), axis: .vertical)
                        .padding(Theme.Spacing.md)
                        .background(.background, in: .rect(cornerRadius: Theme.Radius.field))
                        .accessibilityLabel("Caution note")
                    Button("Remove caution", systemImage: "minus.circle.fill") { viewModel.removeCaution(caution.id) }
                        .labelStyle(.iconOnly)
                        .foregroundStyle(Theme.Palette.danger)
                        .frame(minWidth: Theme.Size.minTapTarget, minHeight: Theme.Size.minTapTarget)
                }
            }
            if viewModel.draft.cautions.count < AppConfig.postMaxCautions {
                Button("Add caution", systemImage: "plus.circle.fill") { viewModel.addCaution() }
                    .font(.subheadline)
                    .frame(minHeight: Theme.Size.minTapTarget)
            }
        }
    }

    // MARK: Calories

    private var hasCalories: Bool {
        viewModel.draft.items.contains { $0.calories != nil }
    }

    private var calories: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Text("Calories (estimate)").font(.subheadline.weight(.semibold))
                Spacer()
                Button(viewModel.showCalories ? "Hide" : "Show") { viewModel.showCalories.toggle() }
                    .font(.subheadline)
                    .frame(minHeight: Theme.Size.minTapTarget)
                    .accessibilityLabel(viewModel.showCalories ? "Hide calorie estimates" : "Show calorie estimates")
            }
            if viewModel.showCalories {
                ForEach(viewModel.draft.items.filter { $0.calories != nil }) { item in
                    if let range = item.calories {
                        Text("\(item.name.isEmpty ? "Item" : item.name): \(range.low)–\(range.high) kcal per serving")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("\(item.name): \(range.low) to \(range.high) calories per serving, estimate")
                    }
                }
            }
        }
    }

    private func cautionBinding(for id: UUID) -> Binding<String> {
        Binding(get: { viewModel.draft.cautions.first { $0.id == id }?.text ?? "" },
                set: { viewModel.setCautionText($0, for: id) })
    }
}
