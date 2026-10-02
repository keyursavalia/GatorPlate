import Foundation
import Testing
@testable import GatorPlate

@MainActor
struct RouteViewModelTests {
    private let onCampus = Coordinate(latitude: 37.7222, longitude: -122.4786)
    private let offCampus = Coordinate(latitude: 37.3349, longitude: -122.0090)

    private func post(_ id: String, latitude: Double = 37.7230) -> FoodPost {
        var post = SampleData.post(id: id)
        post.latitude = latitude
        post.longitude = -122.4780
        return post
    }

    // MARK: Happy path

    @Test func idleToLoadingToRoutedToEnded() async {
        let routing = MockRoutingService()
        let model = RouteViewModel(routing: routing)
        #expect(model.state == .idle)

        model.requestRoute(to: post("a"), from: onCampus)
        #expect(model.state == .loading(postID: "a"))

        await model.waitForCompletion()
        guard case .routed(let summary) = model.state else {
            Issue.record("Expected a route, got \(model.state)")
            return
        }
        #expect(summary.postID == "a")
        #expect(summary.coordinates.count == 2)
        #expect(summary.distanceMeters > 0)
        #expect(summary.travelTime > 0)

        model.endRoute()
        #expect(model.state == .idle)
    }

    @Test func requestSendsUserAsSourceAndPostAsDestination() async {
        let routing = MockRoutingService()
        let model = RouteViewModel(routing: routing)
        let target = post("a")
        model.requestRoute(to: target, from: onCampus)
        await model.waitForCompletion()

        let request = routing.requests.first
        #expect(request?.from == onCampus)
        #expect(request?.to == Coordinate(latitude: target.latitude, longitude: target.longitude))
    }

    // MARK: Failure branches

    @Test func noLocationFailsWithoutCallingTheService() {
        let routing = MockRoutingService()
        let model = RouteViewModel(routing: routing)
        model.requestRoute(to: post("a"), from: nil)
        #expect(model.state == .failed(postID: "a", .noLocation))
        #expect(routing.requests.isEmpty)
    }

    @Test func offCampusFailsWithoutCallingTheService() {
        let routing = MockRoutingService()
        let model = RouteViewModel(routing: routing)
        model.requestRoute(to: post("a"), from: offCampus)
        #expect(model.state == .failed(postID: "a", .offCampus))
        #expect(routing.requests.isEmpty)
    }

    @Test func noRouteFromTheServiceIsReported() async {
        let model = RouteViewModel(routing: MockRoutingService { _, _ in throw RoutingError.noRoute })
        model.requestRoute(to: post("a"), from: onCampus)
        await model.waitForCompletion()
        #expect(model.state == .failed(postID: "a", .noRoute))
    }

    @Test func otherErrorsBecomeNetworkFailures() async {
        let model = RouteViewModel(routing: MockRoutingService { _, _ in throw RoutingError.network })
        model.requestRoute(to: post("a"), from: onCampus)
        await model.waitForCompletion()
        #expect(model.state == .failed(postID: "a", .network))

        let unknown = RouteViewModel(routing: MockRoutingService { _, _ in throw AppError.unknown })
        unknown.requestRoute(to: post("a"), from: onCampus)
        await unknown.waitForCompletion()
        #expect(unknown.state == .failed(postID: "a", .network))
    }

    @Test func retryAfterAFailureCanSucceed() async {
        let attempts = Attempts()
        let model = RouteViewModel(routing: MockRoutingService { from, to in
            if attempts.next() == 1 { throw RoutingError.network }
            return MockRoutingService.straightLine(from, to)
        })
        model.requestRoute(to: post("a"), from: onCampus)
        await model.waitForCompletion()
        #expect(model.state == .failed(postID: "a", .network))
        #expect(RouteFailure.network.canRetry)

        model.requestRoute(to: post("a"), from: onCampus)
        await model.waitForCompletion()
        if case .routed = model.state {} else { Issue.record("Expected a route, got \(model.state)") }
    }

    @Test func failureMessagesAreHelpfulAndOnlyRoutingFailuresRetry() {
        #expect(RouteFailure.offCampus.message.contains("Apple Maps"))
        #expect(RouteFailure.noLocation.message.contains("location"))
        #expect(!RouteFailure.offCampus.canRetry)
        #expect(!RouteFailure.noLocation.canRetry)
        #expect(RouteFailure.noRoute.canRetry)
    }

    // MARK: Cancellation and ordering

    @Test func endingWhileLoadingCancelsAndStaysIdle() async {
        let model = RouteViewModel(routing: MockRoutingService { from, to in
            try await Task.sleep(for: .milliseconds(100))
            return MockRoutingService.straightLine(from, to)
        })
        model.requestRoute(to: post("a"), from: onCampus)
        model.endRoute()
        await model.waitForCompletion()
        try? await Task.sleep(for: .milliseconds(150))
        #expect(model.state == .idle)
    }

    @Test func aSlowEarlierRequestNeverOverwritesALaterOne() async {
        let slowLatitude = 37.7201
        let model = RouteViewModel(routing: MockRoutingService { from, to in
            if to.latitude == slowLatitude {
                // Ignores cancellation on purpose: the stale result must still be dropped.
                do { try await Task.sleep(for: .milliseconds(120)) } catch {}
            }
            return MockRoutingService.straightLine(from, to)
        })
        model.requestRoute(to: post("slow", latitude: slowLatitude), from: onCampus)
        model.requestRoute(to: post("fast"), from: onCampus)
        await model.waitForCompletion()
        try? await Task.sleep(for: .milliseconds(250))

        guard case .routed(let summary) = model.state else {
            Issue.record("Expected a route, got \(model.state)")
            return
        }
        #expect(summary.postID == "fast")
    }

    @Test func endUnlessForKeepsTheRouteOnlyForThatPost() async {
        let model = RouteViewModel(routing: MockRoutingService())
        model.requestRoute(to: post("a"), from: onCampus)
        await model.waitForCompletion()

        model.end(unlessFor: "a")
        if case .routed = model.state {} else { Issue.record("Route should stay for its own post") }

        model.end(unlessFor: "b")
        #expect(model.state == .idle)
    }

    @Test func endUnlessForNilEndsTheRoute() async {
        let model = RouteViewModel(routing: MockRoutingService())
        model.requestRoute(to: post("a"), from: onCampus)
        await model.waitForCompletion()
        model.end(unlessFor: nil)
        #expect(model.state == .idle)
    }
}

private nonisolated final class Attempts: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    func next() -> Int {
        lock.lock()
        defer { lock.unlock() }
        count += 1
        return count
    }
}
