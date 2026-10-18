import Foundation
import Observation

/// "Custom notifications": edits a copy of the saved filters and saves automatically shortly after each change.
/// The categories are always shown. Picking anything switches "All free food" off; clearing every pick (or
/// switching "All free food" back on) returns to all. Filters only choose which notifications this student gets;
/// they're never shown to anyone.
@MainActor
@Observable
final class AlertFiltersViewModel {
    var draft: AlertFilters {
        didSet { syncMode(from: oldValue) }
    }
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
        var draft = settings.alertFilters ?? AlertFilters()
        // Older saves kept picks under "All free food"; they were ignored, so they aren't shown as checked.
        if draft.mode == .all { Self.clearSelections(&draft) }
        self.draft = draft
    }

    var isCustom: Bool { draft.mode == .custom }

    var hasChanges: Bool {
        Self.comparable(draft) != Self.comparable(settings.alertFilters ?? AlertFilters())
    }

    var summary: String {
        isCustom ? "You'll get notifications only for the customized categories."
                 : "You'll get notifications for all food postings on campus."
    }

    /// Any category picked (diet, place, food, allergen, or "skip posts with no allergen info").
    var hasSelections: Bool {
        Self.hasSelections(draft)
    }

    // MARK: Editing

    /// The "All free food" switch. On clears every pick; off waits for the student to pick something.
    func setCustom(_ isCustom: Bool) {
        if isCustom {
            draft.mode = .custom
        } else {
            var cleared = draft
            Self.clearSelections(&cleared)
            draft = cleared
        }
    }

    /// Picking something turns "All free food" off; removing the last pick turns it back on.
    private func syncMode(from oldValue: AlertFilters) {
        let had = Self.hasSelections(oldValue)
        let has = Self.hasSelections(draft)
        if has, draft.mode == .all {
            draft.mode = .custom
        } else if had, !has {
            draft.mode = .all
        }
    }

    private static func hasSelections(_ filters: AlertFilters) -> Bool {
        !filters.diets.isEmpty || !filters.places.isEmpty || !filters.foods.isEmpty
            || !filters.avoidAllergens.isEmpty || filters.skipUnverifiedAllergens
    }

    private static func clearSelections(_ filters: inout AlertFilters) {
        filters.mode = .all
        filters.diets = []
        filters.includeUnknownDiet = false
        filters.places = []
        filters.foods = []
        filters.avoidAllergens = []
        filters.skipUnverifiedAllergens = false
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
