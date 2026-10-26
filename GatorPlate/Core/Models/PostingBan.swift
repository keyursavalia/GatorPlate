import Foundation

/// The admin's decision on an appeal (`appeals/{uid}.resolution`, written by the `resolveAppeal` admin action).
nonisolated enum AppealResolution: String, Sendable {
    /// The pause was lifted.
    case upheld
    /// The pause stays.
    case denied
}

/// A posting pause set by the moderation functions after enough removals in the strike window
/// (`users/{uid}.postingBannedUntil`). Browsing, alerts, reporting and blocking still work.
nonisolated struct PostingBan: Identifiable, Equatable, Sendable {
    var bannedUntil: Date
    /// An appeal for this ban is already in (`appeals/{uid}.bannedUntil` matches).
    var hasAppealed: Bool
    /// The admin's decision on that appeal, once made.
    var appealResolution: AppealResolution?
    /// The admin's short note to the user (at most 200 characters).
    var resolutionNote: String?

    var id: Date { bannedUntil }

    init(bannedUntil: Date, hasAppealed: Bool, appealResolution: AppealResolution? = nil, resolutionNote: String? = nil) {
        self.bannedUntil = bannedUntil
        self.hasAppealed = hasAppealed
        self.appealResolution = appealResolution
        self.resolutionNote = resolutionNote
    }

    func isActive(now: Date = .now) -> Bool { bannedUntil > now }
}
