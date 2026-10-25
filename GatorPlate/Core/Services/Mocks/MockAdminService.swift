import Foundation

#if DEBUG
/// In-memory admin data.
@MainActor
final class MockAdminService: AdminService {
    var isAdmin: Bool
    var appeals: [AdminAppeal]
    var reports: [AdminReport]
    var moderationRecords: [String: AdminModeration] = [:]
    var outcome = AdminActionOutcome(succeeded: true, message: "Done")
    private(set) var actions: [AdminActionRequest] = []

    init(isAdmin: Bool = true, appeals: [AdminAppeal] = [], reports: [AdminReport] = []) {
        self.isAdmin = isAdmin
        self.appeals = appeals
        self.reports = reports
    }

    func refreshAdminStatus() async -> Bool { isAdmin }

    func observeAppeals() -> AsyncThrowingStream<[AdminAppeal], Error> {
        let appeals = appeals
        return AsyncThrowingStream { $0.yield(appeals) }
    }

    func observeReports() -> AsyncThrowingStream<[AdminReport], Error> {
        let reports = reports
        return AsyncThrowingStream { $0.yield(reports) }
    }

    func moderation(uid: String) async throws -> AdminModeration? { moderationRecords[uid] }

    func run(_ action: AdminActionRequest) async throws -> AdminActionOutcome {
        actions.append(action)
        return outcome
    }
}

extension AdminAppeal {
    nonisolated static let sample = AdminAppeal(
        uid: "poster-1", message: "These were real food posts from our club meeting; the reports were from a rival club.",
        bannedUntil: .now.addingTimeInterval(5 * 86_400), createdAt: .now.addingTimeInterval(-3600),
        resolution: nil, resolutionNote: nil)
}

extension AdminReport {
    nonisolated static let sample = AdminReport(
        id: "AbCdEfGhIjKlMnOpQrSt_reporter", postId: "AbCdEfGhIjKlMnOpQrSt", category: .offensive,
        reason: "The photo shows a person's face.", createdAt: .now.addingTimeInterval(-600),
        snapshot: ReportPostSnapshot(title: "Pizza at the Library", description: "Cheese and pepperoni pizza.",
                                     locationName: "J. Paul Leonard Library", authorUid: "poster-1",
                                     authorName: "Sam Lee", orgName: nil),
        aiVerdict: nil, aiConcern: nil, aiRationale: nil)
}
#endif
