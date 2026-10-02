import Foundation
import Observation

enum ReportReason: String, CaseIterable, Identifiable {
    case notFood = "Not food"
    case unsafe = "Unsafe"
    case spam = "Spam"
    case other = "Other"

    var id: String { rawValue }
}

/// Mark as gone (author only) and Report (everyone). Nothing here tracks who looked at or picked up food (R6).
@MainActor
@Observable
final class PostActionsModel {
    enum Notice: Equatable {
        case reported
        case failed(String)
    }

    private(set) var isWorking = false
    private(set) var reportedPostIDs: Set<String> = []
    var notice: Notice?

    @ObservationIgnored private let service: any PostService
    @ObservationIgnored private let currentUserID: String

    init(service: any PostService, currentUserID: String) {
        self.service = service
        self.currentUserID = currentUserID
    }

    func canMarkGone(_ post: FoodPost) -> Bool {
        post.authorUid == currentUserID
    }

    func hasReported(_ post: FoodPost) -> Bool {
        reportedPostIDs.contains(post.id)
    }

    func markGone(_ post: FoodPost) async {
        guard canMarkGone(post), !isWorking else { return }
        isWorking = true
        notice = nil
        defer { isWorking = false }
        do {
            try await service.markGone(postID: post.id)
        } catch {
            notice = .failed(Self.message(for: error, action: "mark this post as gone"))
        }
    }

    func report(_ post: FoodPost, reason: ReportReason) async {
        guard !hasReported(post), !isWorking else { return }
        isWorking = true
        notice = nil
        defer { isWorking = false }
        do {
            try await service.report(postID: post.id, reason: reason.rawValue)
            reportedPostIDs.insert(post.id)
            notice = .reported
        } catch {
            notice = .failed(Self.message(for: error, action: "send your report"))
        }
    }

    static func message(for error: any Error, action: String) -> String {
        switch error as? AppError {
        case .network: "Couldn't reach the server, so we couldn't \(action). Check your connection and try again."
        case .unauthorized: "You can't \(action)."
        default: "Something went wrong and we couldn't \(action). Try again."
        }
    }
}
