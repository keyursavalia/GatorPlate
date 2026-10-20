import SwiftUI

/// What `FoodPickSections` presents: the places sheet and the "Add a food" alert. The parent owns it and attaches
/// `foodPickPresentations` to its `List`, outside the rows: a `.sheet` or `.alert` on a `Section` is copied onto
/// every row, and the copies dismissed the places sheet (and the filter sheet around it).
struct FoodPickPresentation {
    var isPickingPlaces = false
    var isAddingFood = false
    var newFood = ""
}

/// Diet, places, favorite foods and allergens to avoid as checkmark lists, for use inside a `List`. Shared by
/// Custom notifications and the Map/Feed filter so the picks look and behave the same; only the wording differs.
/// The parent applies `foodPickPresentations` to the `List` with the same `presentation` binding.
struct FoodPickSections: View {
    /// The words that differ between notifications ("won't notify you") and browsing ("are hidden").
    struct Wording {
        var unknownDiet: String
        var skipUnverified: String
        var foodsFooter: String
        var addFoodMessage: String
        var allergensFooter: String

        static let notifications = Wording(
            unknownDiet: "Include \"diet unknown\"",
            skipUnverified: "Also skip posts with no allergen info",
            foodsFooter: "None selected means any food. Up to \(AppConfig.alertFilterMaxFoods).",
            addFoodMessage: "You'll get notifications for posts that mention it.",
            allergensFooter: "Posts that may contain these won't notify you.")

        static let browse = Wording(
            unknownDiet: "Include posts with unknown diet",
            skipUnverified: "Hide posts with no allergen info",
            foodsFooter: "None selected means any food. Up to \(AppConfig.alertFilterMaxFoods).",
            addFoodMessage: "Shows posts that mention it.",
            allergensFooter: "Posts that may contain these are hidden.")
    }

    @Binding var picks: AlertFilters
    @Binding var presentation: FoodPickPresentation
    var wording = Wording.notifications
    /// Set by `foodPickPresentations` when "Add a food" fails validation.
    var foodError: String?

    var body: some View {
        dietSection
        placesSection
        foodsSection
        allergensSection
    }

    // MARK: Sections

    private var dietSection: some View {
        Section {
            ForEach(AlertFilters.Diet.allCases, id: \.self) { diet in
                CheckRow(title: diet.displayName,
                         isSelected: picks.diets.contains(diet)) { picks.toggle(diet) }
            }
            if !picks.diets.isEmpty {
                Toggle(wording.unknownDiet, isOn: $picks.includeUnknownDiet)
            }
        } header: {
            Text("Diet")
        } footer: {
            Text("Vegetarian includes vegan food. None selected means any diet.")
        }
    }

    private var placesSection: some View {
        Section {
            ForEach(picks.places, id: \.self) { id in
                HStack {
                    Text(CampusBuilding.byId(id)?.name ?? id)
                    Spacer()
                    Button("Remove", systemImage: "xmark.circle.fill") { picks.removePlace(id) }
                        .labelStyle(.iconOnly)
                        .foregroundStyle(.secondary)
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Remove \(CampusBuilding.byId(id)?.name ?? id)")
                }
            }
            .onDelete { offsets in
                for id in offsets.map({ picks.places[$0] }) { picks.removePlace(id) }
            }
            Button("Add places", systemImage: "plus") { presentation.isPickingPlaces = true }
                .foregroundStyle(Theme.Palette.accent)
        } header: {
            Text("Places")
        } footer: {
            Text("None means anywhere on campus.")
        }
    }

    private var foodsSection: some View {
        Section {
            ForEach(picks.foodRows, id: \.self) { food in
                CheckRow(title: food, isSelected: picks.isFoodSelected(food)) { picks.toggleFood(food) }
            }
            Button("Custom", systemImage: "plus") {
                presentation.newFood = ""
                presentation.isAddingFood = true
            }
            .foregroundStyle(Theme.Palette.accent)
            .disabled(picks.foods.count >= AppConfig.alertFilterMaxFoods)
        } header: {
            Text("Favorite foods")
        } footer: {
            if let foodError {
                Text(foodError).foregroundStyle(Theme.Palette.danger)
            } else {
                Text(wording.foodsFooter)
            }
        }
    }

    private var allergensSection: some View {
        Section {
            ForEach(Allergen.allCases, id: \.self) { allergen in
                CheckRow(title: allergen.displayName, isSelected: picks.avoidAllergens.contains(allergen)) {
                    picks.toggle(allergen)
                }
            }
            Toggle(wording.skipUnverified, isOn: $picks.skipUnverifiedAllergens)
        } header: {
            Text("Avoid allergens")
        } footer: {
            Text(wording.allergensFooter)
        }
    }

}

extension View {
    /// The places sheet and "Add a food" alert for `FoodPickSections`. Apply to the `List`, never to a row or
    /// section. `foodError` is set when the typed food is rejected and cleared on the next pick.
    func foodPickPresentations(_ presentation: Binding<FoodPickPresentation>, picks: Binding<AlertFilters>,
                               wording: FoodPickSections.Wording, foodError: Binding<String?>) -> some View {
        modifier(FoodPickPresentations(presentation: presentation, picks: picks, wording: wording,
                                       foodError: foodError))
    }
}

private struct FoodPickPresentations: ViewModifier {
    @Binding var presentation: FoodPickPresentation
    @Binding var picks: AlertFilters
    let wording: FoodPickSections.Wording
    @Binding var foodError: String?

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $presentation.isPickingPlaces) {
                PlacesPickerSheet(selected: picks.places) { picks.setPlaces($0) }
            }
            .alert("Add a food", isPresented: $presentation.isAddingFood) {
                TextField("e.g. tacos", text: $presentation.newFood)
                    .textInputAutocapitalization(.never)
                Button("Add", action: addFood)
                Button("Cancel", role: .cancel) { presentation.newFood = "" }
            } message: {
                Text(wording.addFoodMessage)
            }
            .onChange(of: picks.foods) { foodError = nil }
    }

    private func addFood() {
        foodError = nil
        do {
            if try picks.addFood(presentation.newFood) { presentation.newFood = "" }
        } catch {
            foodError = error.message
        }
    }
}
