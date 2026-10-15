import SwiftUI

/// Settings > Alerts > What to alert me about. A live summary card, "All free food" or "Only what I choose",
/// then diet, places, favorite foods and allergens to avoid. Explicit Save; leaving with changes asks first.
struct AlertFiltersView: View {
    @State private var viewModel: AlertFiltersViewModel
    @State private var newFood = ""
    @State private var isPickingPlaces = false
    @State private var isConfirmingLeave = false
    @Environment(\.dismiss) private var dismiss

    init(settings: SettingsViewModel, repository: PostsRepository) {
        _viewModel = State(initialValue: AlertFiltersViewModel(settings: settings, repository: repository))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                if !viewModel.isEnabled {
                    Banner(style: .info, message: "Turn on alerts first. Filters choose which alerts you get.")
                }
                summaryCard
                Picker("Alerts for", selection: customBinding) {
                    Text("All free food").tag(false)
                    Text("Only what I choose").tag(true)
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("Alerts for")

                Group {
                    dietCard
                    placesCard
                    foodsCard
                    allergensCard
                }
                .disabled(!viewModel.isCustom)
                .opacity(viewModel.isCustom ? 1 : 0.5)

                Text("Filters only choose which alerts you get. AI labels can be wrong. Always confirm with the host.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if let error = viewModel.errorMessage {
                    Banner(style: .error, message: error)
                }
            }
            .padding(Theme.Spacing.lg)
            .disabled(!viewModel.isEnabled)
        }
        .navigationTitle("What to alert me about")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(viewModel.hasChanges)
        .toolbar {
            if viewModel.hasChanges {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Back") { isConfirmingLeave = true }
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                if viewModel.isSaving {
                    ProgressView()
                } else {
                    Button("Save") { Task { await save(thenLeave: false) } }
                        .disabled(!viewModel.hasChanges || !viewModel.isEnabled)
                }
            }
        }
        .confirmationDialog("Save your changes?", isPresented: $isConfirmingLeave, titleVisibility: .visible) {
            Button("Save") { Task { await save(thenLeave: true) } }
            Button("Discard", role: .destructive) {
                viewModel.discard()
                dismiss()
            }
            Button("Keep editing", role: .cancel) {}
        }
        .sheet(isPresented: $isPickingPlaces) {
            PlacesPickerSheet(selected: viewModel.draft.places, onDone: viewModel.setPlaces)
        }
        .onChange(of: viewModel.summary) { _, summary in
            AccessibilityNotification.Announcement(summary).post()
        }
    }

    // MARK: Cards

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(viewModel.summary).font(.headline)
            Text(viewModel.matchLine).font(.subheadline).foregroundStyle(.secondary)
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Palette.brandPurple.opacity(0.1), in: .rect(cornerRadius: Theme.Radius.card))
        .accessibilityElement(children: .combine)
    }

    private var dietCard: some View {
        SectionCard(title: "Diet", systemImage: "leaf") {
            FlowLayout {
                ForEach(AlertFilters.Diet.allCases, id: \.self) { diet in
                    ToggleChip(title: diet == .vegan ? "Vegan" : "Vegetarian", systemImage: "leaf",
                               isSelected: viewModel.draft.diets.contains(diet)) { viewModel.toggle(diet) }
                }
            }
            Toggle("Include \"diet unknown\"", isOn: $viewModel.draft.includeUnknownDiet)
                .disabled(viewModel.draft.diets.isEmpty)
            Text("Vegetarian includes vegan food. No diet selected means any diet.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var placesCard: some View {
        SectionCard(title: "Places", systemImage: "mappin.and.ellipse") {
            if viewModel.draft.places.isEmpty {
                Text("Anywhere on campus").font(.subheadline)
            } else {
                FlowLayout {
                    ForEach(viewModel.draft.places, id: \.self) { id in
                        ToggleChip(title: CampusBuilding.byId(id)?.shortName ?? id, systemImage: "mappin",
                                   isSelected: true) { viewModel.removePlace(id) }
                            .accessibilityHint("Removes this place")
                    }
                }
            }
            Button(viewModel.draft.places.isEmpty ? "Choose places" : "Add places", systemImage: "plus.circle.fill") {
                isPickingPlaces = true
            }
            .frame(minHeight: Theme.Size.minTapTarget)
        }
    }

    private var foodsCard: some View {
        SectionCard(title: "Favorite foods", systemImage: "heart") {
            if !viewModel.draft.foods.isEmpty {
                FlowLayout {
                    ForEach(viewModel.draft.foods, id: \.self) { food in
                        ToggleChip(title: food, isSelected: true) { viewModel.removeFood(food) }
                            .accessibilityHint("Removes this food")
                    }
                }
            }
            HStack {
                TextField("Add a food, e.g. pizza", text: $newFood)
                    .textInputAutocapitalization(.never)
                    .submitLabel(.done)
                    .onSubmit(addFood)
                    .padding(Theme.Spacing.md)
                    .background(.background, in: .rect(cornerRadius: Theme.Radius.field))
                Button("Add", action: addFood)
                    .disabled(newFood.trimmingCharacters(in: .whitespaces).isEmpty)
                    .frame(minHeight: Theme.Size.minTapTarget)
            }
            if let error = viewModel.foodError {
                Label(error, systemImage: "exclamationmark.circle").font(.footnote).foregroundStyle(Theme.Palette.danger)
            }
            Text("Suggestions").font(.footnote).foregroundStyle(.secondary)
            FlowLayout {
                ForEach(AlertFiltersViewModel.foodSuggestions, id: \.self) { food in
                    if !viewModel.draft.foods.contains(where: { $0.caseInsensitiveCompare(food) == .orderedSame }) {
                        ToggleChip(title: food, isSelected: false) { viewModel.addFood(food) }
                    }
                }
            }
        }
    }

    private var allergensCard: some View {
        SectionCard(title: "Avoid allergens", systemImage: "exclamationmark.triangle") {
            FlowLayout {
                ForEach(Allergen.allCases, id: \.self) { allergen in
                    ToggleChip(title: allergen.displayName, systemImage: "exclamationmark.triangle",
                               isSelected: viewModel.draft.avoidAllergens.contains(allergen),
                               tint: Theme.Palette.warning) { viewModel.toggle(allergen) }
                }
            }
            Toggle("Also skip posts with no allergen info", isOn: $viewModel.draft.skipUnverifiedAllergens)
        }
    }

    // MARK: Actions

    private var customBinding: Binding<Bool> {
        Binding(get: { viewModel.isCustom }, set: { viewModel.setCustom($0) })
    }

    private func addFood() {
        if viewModel.addFood(newFood) { newFood = "" }
    }

    private func save(thenLeave: Bool) async {
        if await viewModel.save() {
            AccessibilityNotification.Announcement("Alert filters saved").post()
            if thenLeave { dismiss() }
        }
    }
}
