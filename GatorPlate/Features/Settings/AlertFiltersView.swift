import SwiftUI

/// Settings > Notifications > Custom notifications (reachable only while notifications are on). An "All free food"
/// switch (on by default) above checklists that are always shown: diet, places, favorite foods (with "+ Custom")
/// and allergens to avoid. Picking anything turns the switch off. Every change saves on its own a moment later.
struct AlertFiltersView: View {
    @State private var viewModel: AlertFiltersViewModel
    @State private var newFood = ""
    @State private var isAddingFood = false
    @State private var isPickingPlaces = false

    init(settings: SettingsViewModel) {
        _viewModel = State(initialValue: AlertFiltersViewModel(settings: settings))
    }

    var body: some View {
        List {
            Section {
                Toggle("All free food", isOn: allFoodBinding)
                    .font(.body.weight(.semibold))
            } footer: {
                Text(viewModel.summary)
            }

            if let error = viewModel.errorMessage {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(Theme.Palette.danger)
                    Button("Try again") { viewModel.scheduleSave() }
                }
            }

            dietSection
            placesSection
            foodsSection
            allergensSection

            Section {
                NoteRow(text: "These only choose which notifications you get. AI labels can be wrong, so always confirm with the host.",
                        systemImage: "sparkles")
            }
        }
        .environment(\.defaultMinListRowHeight, 48)
        .navigationTitle("Custom notifications")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: viewModel.draft) { viewModel.scheduleSave() }
        .onDisappear { viewModel.flush() }
        .sheet(isPresented: $isPickingPlaces) {
            PlacesPickerSheet(selected: viewModel.draft.places, onDone: viewModel.setPlaces)
        }
        .alert("Add a food", isPresented: $isAddingFood) {
            TextField("e.g. tacos", text: $newFood)
                .textInputAutocapitalization(.never)
            Button("Add", action: addFood)
            Button("Cancel", role: .cancel) { newFood = "" }
        } message: {
            Text("You'll get notifications for posts that mention it.")
        }
        .onChange(of: viewModel.summary) { _, summary in
            AccessibilityNotification.Announcement(summary).post()
        }
    }

    // MARK: Sections

    private var dietSection: some View {
        Section {
            ForEach(AlertFilters.Diet.allCases, id: \.self) { diet in
                CheckRow(title: diet == .vegan ? "Vegan" : "Vegetarian",
                         isSelected: viewModel.draft.diets.contains(diet)) { viewModel.toggle(diet) }
            }
            if !viewModel.draft.diets.isEmpty {
                Toggle("Include \"diet unknown\"", isOn: $viewModel.draft.includeUnknownDiet)
            }
        } header: {
            Text("Diet")
        } footer: {
            Text("Vegetarian includes vegan food. None selected means any diet.")
        }
    }

    private var placesSection: some View {
        Section {
            ForEach(viewModel.draft.places, id: \.self) { id in
                HStack {
                    Text(CampusBuilding.byId(id)?.name ?? id)
                    Spacer()
                    Button("Remove", systemImage: "xmark.circle.fill") { viewModel.removePlace(id) }
                        .labelStyle(.iconOnly)
                        .foregroundStyle(.secondary)
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Remove \(CampusBuilding.byId(id)?.name ?? id)")
                }
            }
            .onDelete { offsets in
                for id in offsets.map({ viewModel.draft.places[$0] }) { viewModel.removePlace(id) }
            }
            Button("Add places", systemImage: "plus") { isPickingPlaces = true }
                .foregroundStyle(Theme.Palette.brandPurple)
        } header: {
            Text("Places")
        } footer: {
            Text("None means anywhere on campus.")
        }
    }

    private var foodsSection: some View {
        Section {
            ForEach(viewModel.foodRows, id: \.self) { food in
                CheckRow(title: food, isSelected: viewModel.isFoodSelected(food)) { viewModel.toggleFood(food) }
            }
            Button("Custom", systemImage: "plus") {
                newFood = ""
                isAddingFood = true
            }
            .foregroundStyle(Theme.Palette.brandPurple)
            .disabled(viewModel.draft.foods.count >= AppConfig.alertFilterMaxFoods)
        } header: {
            Text("Favorite foods")
        } footer: {
            if let error = viewModel.foodError {
                Text(error).foregroundStyle(Theme.Palette.danger)
            } else {
                Text("None selected means any food. Up to \(AppConfig.alertFilterMaxFoods).")
            }
        }
    }

    private var allergensSection: some View {
        Section {
            ForEach(Allergen.allCases, id: \.self) { allergen in
                CheckRow(title: allergen.displayName, isSelected: viewModel.draft.avoidAllergens.contains(allergen)) {
                    viewModel.toggle(allergen)
                }
            }
            Toggle("Also skip posts with no allergen info", isOn: $viewModel.draft.skipUnverifiedAllergens)
        } header: {
            Text("Avoid allergens")
        } footer: {
            Text("Posts that may contain these won't notify you.")
        }
    }

    // MARK: Actions

    private var allFoodBinding: Binding<Bool> {
        Binding(get: { !viewModel.isCustom }, set: { viewModel.setCustom(!$0) })
    }

    private func addFood() {
        if viewModel.addFood(newFood) { newFood = "" }
    }
}
