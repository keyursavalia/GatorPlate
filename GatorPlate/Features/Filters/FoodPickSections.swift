import SwiftUI

/// Diet, places, favorite foods and allergens to avoid as checkmark lists, for use inside a `List`. Shared by
/// Custom notifications and the Map/Feed filter so the picks look and behave the same; only the wording differs.
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
    var wording = Wording.notifications

    @State private var newFood = ""
    @State private var isAddingFood = false
    @State private var isPickingPlaces = false
    @State private var foodError: String?

    var body: some View {
        Group {
            dietSection
            placesSection
            foodsSection
            allergensSection
        }
        .sheet(isPresented: $isPickingPlaces) {
            PlacesPickerSheet(selected: picks.places) { picks.setPlaces($0) }
        }
        .alert("Add a food", isPresented: $isAddingFood) {
            TextField("e.g. tacos", text: $newFood)
                .textInputAutocapitalization(.never)
            Button("Add", action: addFood)
            Button("Cancel", role: .cancel) { newFood = "" }
        } message: {
            Text(wording.addFoodMessage)
        }
    }

    // MARK: Sections

    private var dietSection: some View {
        Section {
            ForEach(AlertFilters.Diet.allCases, id: \.self) { diet in
                CheckRow(title: diet == .vegan ? "Vegan" : "Vegetarian",
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
            Button("Add places", systemImage: "plus") { isPickingPlaces = true }
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
                CheckRow(title: food, isSelected: picks.isFoodSelected(food)) {
                    foodError = nil
                    picks.toggleFood(food)
                }
            }
            Button("Custom", systemImage: "plus") {
                newFood = ""
                isAddingFood = true
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

    private func addFood() {
        foodError = nil
        do {
            if try picks.addFood(newFood) { newFood = "" }
        } catch {
            foodError = error.message
        }
    }
}
