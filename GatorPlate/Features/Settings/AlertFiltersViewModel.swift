import Foundation
import Observation

/// "What to alert me about": edits a copy of the saved filters, previews them live against the posts on the map,
/// and saves explicitly. Filters only choose which alerts this student gets; they're never shown to anyone.
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
    @ObservationIgnored private let repository: PostsRepository

    init(settings: SettingsViewModel, repository: PostsRepository) {
        self.settings = settings
        self.repository = repository
        self.draft = settings.alertFilters ?? AlertFilters()
    }

    /// Filters apply only while alerts are on.
    var isEnabled: Bool { settings.alertsEnabled }

    var isCustom: Bool { draft.mode == .custom }

    var hasChanges: Bool {
        Self.comparable(draft) != Self.comparable(settings.alertFilters ?? AlertFilters())
    }

    var summary: String { AlertFilterSummary.sentence(for: draft) }

    /// "Right now 2 of 5 posts match." Uses the same logic as the alert function.
    var matchLine: String {
        let posts = repository.activePosts
        guard !posts.isEmpty else { return "No posts right now to compare with." }
        let matching = posts.filter { AlertFilterMatcher.matches($0, filters: draft) }.count
        return "Right now \(matching) of \(posts.count) \(posts.count == 1 ? "post matches" : "posts match")."
    }

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
        draft.foods.removeAll { $0 == food }
    }

    // MARK: Saving

    func save() async -> Bool {
        guard !isSaving else { return false }
        errorMessage = nil
        isSaving = true
        defer { isSaving = false }
        do {
            try await settings.saveAlertFilters(draft)
            return true
        } catch {
            errorMessage = (error as? AppError)?.userMessage ?? AppError.unknown.userMessage
            return false
        }
    }

    func discard() {
        draft = settings.alertFilters ?? AlertFilters()
        errorMessage = nil
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
