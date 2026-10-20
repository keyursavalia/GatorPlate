import Foundation

/// A posting pause set by the `onReportCreated` function after a 4th post was removed within 30 days
/// (`users/{uid}.postingBannedUntil`). Browsing, alerts and reporting still work.
nonisolated struct PostingBan: Identifiable, Equatable, Sendable {
    var bannedUntil: Date
    /// An appeal for this ban is already in (`appeals/{uid}.bannedUntil` matches).
    var hasAppealed: Bool

    var id: Date { bannedUntil }

    func isActive(now: Date = .now) -> Bool { bannedUntil > now }
}
