import Foundation
import Observation

/// Posts this account has reported, saved on this phone only (`reports.hidden.<uid>`: post ID -> when the post ends).
/// The Map and Feed hide them right away, before any removal; each entry is dropped once its post has ended.
/// Removed with the other per-user defaults when the account is deleted (`AccountCleanup`).
@MainActor
@Observable
final class ReportedPosts {
    nonisolated static let keyPrefix = "reports.hidden."

    private(set) var ids: Set<String> = []

    @ObservationIgnored private var expiries: [String: Date]
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let key: String

    init(uid: String, defaults: UserDefaults = .standard, now: Date = .now) {
        self.defaults = defaults
        key = Self.keyPrefix + uid
        let stored = defaults.dictionary(forKey: key) as? [String: Date] ?? [:]
        expiries = stored.filter { $0.value > now }
        ids = Set(expiries.keys)
        if expiries.count != stored.count { save() }
    }

    func contains(_ postId: String) -> Bool {
        ids.contains(postId)
    }

    func insert(_ post: FoodPost, now: Date = .now) {
        expiries = expiries.filter { $0.value > now }
        expiries[post.id] = post.expiresAt
        ids = Set(expiries.keys)
        save()
    }

    private func save() {
        if expiries.isEmpty {
            defaults.removeObject(forKey: key)
        } else {
            defaults.set(expiries, forKey: key)
        }
    }
}
