import Foundation
import Observation

/// The Map/Feed filter and the Feed sort for one guest or account, saved on this phone only
/// (`browse.filter.<uid>`, `browse.sort.<uid>`). Diet and allergen picks can be sensitive (R6), so they're never
/// written to Firestore, never logged and never sent anywhere. Removed with the other per-user defaults when the
/// account is deleted (`AccountCleanup`).
@MainActor
@Observable
final class PostFilterStore {
    nonisolated static let filterKeyPrefix = "browse.filter."
    nonisolated static let sortKeyPrefix = "browse.sort."

    var filter: PostFilter {
        didSet { if filter != oldValue { saveFilter() } }
    }
    var sort: FeedSort {
        didSet { if sort != oldValue { defaults.set(sort.rawValue, forKey: sortKey) } }
    }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let filterKey: String
    @ObservationIgnored private let sortKey: String

    init(uid: String, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        filterKey = Self.filterKeyPrefix + uid
        sortKey = Self.sortKeyPrefix + uid
        filter = defaults.data(forKey: filterKey)
            .flatMap { try? JSONDecoder().decode(PostFilter.self, from: $0) } ?? PostFilter()
        sort = defaults.string(forKey: sortKey).flatMap(FeedSort.init(rawValue:)) ?? .newest
    }

    /// "Reset" / "Clear filters". The sort stays.
    func clear() {
        filter = PostFilter()
    }

    private func saveFilter() {
        if filter.isEmpty {
            defaults.removeObject(forKey: filterKey)
        } else if let data = try? JSONEncoder().encode(filter) {
            defaults.set(data, forKey: filterKey)
        }
    }
}
