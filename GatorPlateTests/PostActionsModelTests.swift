import Foundation
import Testing
@testable import GatorPlate

@MainActor
struct PostActionsModelTests {
    private func post(author: String = "author") -> FoodPost {
        var post = SampleData.post(id: "p1")
        post.authorUid = author
        return post
    }

    private func makeModel(user: String = "author", service: MockPostService) -> PostActionsModel {
        PostActionsModel(service: service, currentUserID: user)
    }

    @Test func onlyTheAuthorCanMarkGone() {
        let service = MockPostService(posts: [])
        #expect(makeModel(user: "author", service: service).canMarkGone(post()))
        #expect(!makeModel(user: "someone-else", service: service).canMarkGone(post()))
    }

    @Test func markGoneByAuthorUpdatesTheService() async {
        let service = MockPostService(posts: [post()])
        let model = makeModel(service: service)
        await model.markGone(post())
        let stored = await service.allPosts()
        #expect(stored.first?.status == .gone)
        #expect(model.notice == nil)
    }

    @Test func markGoneByANonAuthorDoesNothing() async {
        let service = MockPostService(posts: [post()])
        let model = makeModel(user: "someone-else", service: service)
        await model.markGone(post())
        let stored = await service.allPosts()
        #expect(stored.first?.status == .active)
    }

    @Test func markGoneFailureShowsAFriendlyNotice() async {
        let service = MockPostService(posts: [])
        let model = makeModel(service: service)
        await model.markGone(post())
        guard case .failed(let message) = model.notice else {
            Issue.record("Expected a failure notice")
            return
        }
        #expect(message.contains("mark this post as gone"))
        #expect(!model.isWorking)
    }

    @Test func reportStoresTheReasonAndThanksTheUser() async {
        let service = MockPostService(posts: [post()])
        let model = makeModel(user: "someone-else", service: service)
        await model.report(post(), reason: .unsafe)
        let reports = await service.reports
        #expect(reports.count == 1)
        #expect(reports.first?.postID == "p1")
        #expect(reports.first?.reason == "Unsafe")
        #expect(model.notice == .reported)
        #expect(model.hasReported(post()))
    }

    @Test func aPostCanOnlyBeReportedOncePerSession() async {
        let service = MockPostService(posts: [post()])
        let model = makeModel(user: "someone-else", service: service)
        await model.report(post(), reason: .spam)
        await model.report(post(), reason: .spam)
        let reports = await service.reports
        #expect(reports.count == 1)
    }

    @Test func reportReasonsMatchTheSpec() {
        #expect(ReportReason.allCases.map(\.rawValue) == ["Not food", "Unsafe", "Spam", "Other"])
    }

    @Test func errorMessagesDependOnTheError() {
        #expect(PostActionsModel.message(for: AppError.network, action: "do it").contains("connection"))
        #expect(PostActionsModel.message(for: AppError.unauthorized, action: "do it").contains("can't"))
        #expect(PostActionsModel.message(for: AppError.unknown, action: "do it").contains("Try again"))
    }
}
