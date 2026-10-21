import Foundation

/// A posting-pause appeal as the admin sees it (`appeals/{uid}`).
nonisolated struct AdminAppeal: Identifiable, Equatable, Sendable {
    /// The poster's uid (the doc ID).
    let uid: String
    let message: String
    let bannedUntil: Date
    let createdAt: Date
    let resolution: AppealResolution?
    let resolutionNote: String?

    var id: String { uid }
    var isOpen: Bool { resolution == nil }
}

/// The reported post as it was when reported (`reports.postSnapshot`).
nonisolated struct ReportPostSnapshot: Equatable, Sendable {
    let title: String
    let description: String
    let locationName: String
    let authorUid: String
    let authorName: String
    let orgName: String?

    var posterName: String { orgName ?? authorName }
}

/// A report as the admin sees it (`reports/{postId}_{uid}`). Never shows who reported.
nonisolated struct AdminReport: Identifiable, Equatable, Sendable {
    let id: String
    let postId: String
    let category: ReportCategory
    let reason: String?
    let createdAt: Date
    let snapshot: ReportPostSnapshot?
    /// credible, notCredible, unavailable or disabled (unsafe reports only).
    let aiVerdict: String?
    let aiConcern: String?
    let aiRationale: String?
    /// Set by the functions when the post is removed or an admin dismisses the reports; nil while it needs review.
    var resolution: ReportResolution?
    /// True when an admin closed it; false for automatic removals (reports, photo screening, text filter).
    var resolvedByAdmin = false
    var resolvedAt: Date?

    var isOpen: Bool { resolution == nil }

    /// "Removed by an admin", "Removed automatically" or "Dismissed"; nil while open.
    var outcomeLabel: String? {
        switch resolution {
        case .removed: resolvedByAdmin ? "Removed by an admin" : "Removed automatically"
        case .dismissed: "Dismissed"
        case nil: nil
        }
    }

    /// Offensive first, then unchecked unsafe reports, then the rest; newest first within each.
    static func reviewOrder(_ lhs: AdminReport, _ rhs: AdminReport) -> Bool {
        if lhs.priority != rhs.priority { return lhs.priority < rhs.priority }
        return lhs.createdAt > rhs.createdAt
    }

    private var priority: Int {
        if category == .offensive { return 0 }
        if category == .unsafe, aiVerdict == "unavailable" || aiVerdict == "disabled" { return 1 }
        return 2
    }
}

/// How a report was closed (`reports.resolution`): its post was removed, or an admin kept the post.
nonisolated enum ReportResolution: String, Sendable {
    case removed
    case dismissed
}

/// A poster's moderation record (`moderation/{uid}`).
nonisolated struct AdminModeration: Equatable, Sendable {
    struct Removal: Equatable, Sendable, Identifiable {
        let postId: String
        let category: String
        let removedAt: Date
        var id: String { postId }
    }

    let removals: [Removal]
    let bannedUntil: Date?
    let blockedByCount: Int
}

/// An `adminActions` doc the app writes for the admin; `onAdminActionCreated` does the work.
nonisolated enum AdminActionRequest: Equatable, Sendable {
    case removePost(postId: String, strike: Bool)
    /// Keeps the post and closes its open reports.
    case dismissReports(postId: String)
    case resolveAppeal(uid: String, upheld: Bool, clearStrikes: Bool, note: String?)
    case liftBan(uid: String, clearStrikes: Bool)
    case clearStrikes(uid: String)

    /// The doc fields (besides `createdBy` / `createdAt`), as the function expects them.
    var fields: [String: Any] {
        switch self {
        case .removePost(let postId, let strike):
            ["action": "removePost", "postId": postId, "strike": strike]
        case .dismissReports(let postId):
            ["action": "dismissReports", "postId": postId]
        case .resolveAppeal(let uid, let upheld, let clearStrikes, let note):
            ["action": "resolveAppeal", "uid": uid, "decision": upheld ? "upheld" : "denied",
             "clearStrikes": clearStrikes].merging(note.map { ["note": $0] } ?? [:]) { first, _ in first }
        case .liftBan(let uid, let clearStrikes):
            ["action": "liftBan", "uid": uid, "clearStrikes": clearStrikes]
        case .clearStrikes(let uid):
            ["action": "clearStrikes", "uid": uid]
        }
    }
}

/// How an admin action ended (`adminActions/{id}.status` and `result`).
nonisolated struct AdminActionOutcome: Equatable, Sendable {
    let succeeded: Bool
    let message: String
}
