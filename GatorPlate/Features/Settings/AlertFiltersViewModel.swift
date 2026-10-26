import Foundation
import Observation

/// "Custom notifications": edits a copy of the saved filters and saves automatically shortly after each change.
/// The categories are always shown. Picking anything switches "All free food" off; clearing every pick (or
/// switching "All free food" back on) returns to all. Filters only choose which notifications this student gets;
/// they're never shown to anyone. Editing the picks themselves lives in `AlertFilters+Picks` (shared with the
/// Map/Feed filter).
@MainActor
@Observable
final class AlertFiltersViewModel {
    var draft: AlertFilters {
        didSet { syncMode(from: oldValue) }
    }
    private(set) var isSaving = false
    private(set) var errorMessage: String?

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

    /// The "All free food" switch. On clears every pick. It only turns off by picking something, so it never
    /// says "customized" while nothing is filtered.
    func setCustom(_ isCustom: Bool) {
        if isCustom {
            guard hasSelections else { return }
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
        filters.hasPicks
    }

    private static func clearSelections(_ filters: inout AlertFilters) {
        filters.mode = .all
        filters.clearPicks()
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

    private static func comparable(_ filters: AlertFilters) -> AlertFilters {
        var copy = filters
        copy.updatedAt = nil
        return copy
    }
}
