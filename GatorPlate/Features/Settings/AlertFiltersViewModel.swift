import Foundation
import Observation

/// "What to alert me about": edits a copy of the saved filters and saves automatically shortly after each change.
/// Filters only choose which alerts this student gets; they're never shown to anyone.
@MainActor
@Observable
final class AlertFiltersViewModel {
    var draft: AlertFilters
    private(set) var isSaving = false
    private(set) var errorMessage: String?
    /// Inline message for the "add a food" field.
    private(set) var foodError: String?

    static let foodSuggestions = ["Pizza", "Boba", "Coffee", "Dessert", "Snacks", "Fruit"]

    @ObservationIgnored private let settings: SettingsViewModel
    @ObservationIgnored private var saveTask: Task<Void, Never>?

    /// Changes are saved this long after the last tap, so quick taps become one write.
    static let autosaveDelay = Duration.milliseconds(600)

    init(settings: SettingsViewModel) {
        self.settings = settings
        self.draft = settings.alertFilters ?? AlertFilters()
    }

    var isCustom: Bool { draft.mode == .custom }

    var hasChanges: Bool {
        Self.comparable(draft) != Self.comparable(settings.alertFilters ?? AlertFilters())
    }

    var summary: String { AlertFilterSummary.sentence(for: draft) }

    // MARK: Editing

    func setCustom(_ isCustom: Bool) {
        draft.mode = isCustom ? .custom : .all
    }

    func toggle(_ diet: AlertFilters.Diet) {
        toggle(diet, in: &draft.diets)
    }

    func toggle(_ allergen: Allergen) {
        let wasEmpty = draft.avoidAllergens.isEmpty
        toggle(allergen, in: &draft.avoidAllergens)
        // Suggested on when the student starts avoiding something; they can turn it off.
        if wasEmpty, !draft.avoidAllergens.isEmpty { draft.skipUnverifiedAllergens = true }
    }

    func setPlaces(_ ids: [String]) {
        draft.places = Array(ids.prefix(AppConfig.alertFilterMaxPlaces))
    }

    func removePlace(_ id: String) {
        draft.places.removeAll { $0 == id }
    }

    /// True when added. Trimmed, 1-30 characters, at most 10, no duplicates.
    @discardableResult
    func addFood(_ raw: String) -> Bool {
        foodError = nil
        let food = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !food.isEmpty else { return false }
        guard food.count <= AppConfig.alertFilterFoodMaxLength else {
            foodError = "Keep it under \(AppConfig.alertFilterFoodMaxLength) characters."
            return false
        }
        guard draft.foods.count < AppConfig.alertFilterMaxFoods else {
            foodError = "Up to \(AppConfig.alertFilterMaxFoods) foods."
            return false
        }
        guard !draft.foods.contains(where: { $0.caseInsensitiveCompare(food) == .orderedSame }) else { return false }
        draft.foods.append(food)
        return true
    }

    func removeFood(_ food: String) {
        draft.foods.removeAll { $0.caseInsensitiveCompare(food) == .orderedSame }
    }

    func isFoodSelected(_ food: String) -> Bool {
        draft.foods.contains { $0.caseInsensitiveCompare(food) == .orderedSame }
    }

    func toggleFood(_ food: String) {
        if isFoodSelected(food) { removeFood(food) } else { addFood(food) }
    }

    /// Suggestions first, then the student's own foods, each once.
    var foodRows: [String] {
        let custom = draft.foods.filter { food in
            !Self.foodSuggestions.contains { $0.caseInsensitiveCompare(food) == .orderedSame }
        }
        return Self.foodSuggestions + custom
    }

    // MARK: Saving

    /// Call after every change: saves once the taps settle.
    func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: Self.autosaveDelay)
            guard !Task.isCancelled else { return }
            await self?.save()
        }
    }

    /// Leaving the screen: save a pending change now.
    func flush() {
        guard hasChanges else { return }
        saveTask?.cancel()
        saveTask = Task { await save() }
    }

    private func save() async {
        guard hasChanges else { return }
        guard !isSaving else {
            // A save is running; save again with the newest draft after it.
            scheduleSave()
            return
        }
        errorMessage = nil
        isSaving = true
        defer { isSaving = false }
        do {
            try await settings.saveAlertFilters(draft)
        } catch {
            errorMessage = (error as? AppError)?.userMessage ?? AppError.unknown.userMessage
        }
    }

    private func toggle<T: Equatable>(_ value: T, in list: inout [T]) {
        if let index = list.firstIndex(of: value) {
            list.remove(at: index)
        } else {
            list.append(value)
        }
    }

    private static func comparable(_ filters: AlertFilters) -> AlertFilters {
        var copy = filters
        copy.updatedAt = nil
        return copy
    }
}
