import Foundation

/// A poster this user blocked (`blocks/{blockerUid}_{blockedUid}`). One-directional: the blocked person isn't told.
nonisolated struct BlockedUser: Identifiable, Equatable, Sendable {
    let uid: String
    /// The poster's display (or org) name when they were blocked.
    let name: String
    let blockedAt: Date

    var id: String { uid }
}
