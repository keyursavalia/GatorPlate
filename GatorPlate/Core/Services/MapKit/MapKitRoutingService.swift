import MapKit
import OSLog
import Synchronization

/// Walking routes from `MKDirections`. Uses the completion-handler API (called on the main queue) because
/// `MKDirections.Response` and `MKRoute` are not Sendable; only plain values leave this file.
@MainActor
final class MapKitRoutingService: RoutingService {
    func walkingRoute(from origin: Coordinate, to destination: Coordinate) async throws -> WalkingRoute {
        let request = MKDirections.Request()
        request.source = MKMapItem(location: origin.clLocation, address: nil)
        request.destination = MKMapItem(location: destination.clLocation, address: nil)
        request.transportType = .walking
        request.requestsAlternateRoutes = false

        let start = ContinuousClock.now
        let result = await DirectionsCall(MKDirections(request: request))
            .run(deadlineSeconds: AppConfig.routeTimeoutSeconds)
        let elapsed = (ContinuousClock.now - start).formatted(.units(allowed: [.milliseconds]))
        switch result {
        case .success(let route):
            Logger.services.info("Walking route in \(elapsed, privacy: .public), \(route.coordinates.count, privacy: .public) points")
            return route
        case .failure(let failure):
            // Category only: never log coordinates.
            Logger.services.error("Walking route failed after \(elapsed, privacy: .public): \(String(describing: failure), privacy: .public)")
            throw failure
        }
    }

    func openInAppleMaps(to destination: Coordinate, name: String) {
        let item = MKMapItem(location: destination.clLocation, address: nil)
        item.name = name
        let opened = item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking])
        if !opened { Logger.services.error("Open in Apple Maps failed") }
    }

    fileprivate nonisolated static func outcome(_ response: MKDirections.Response?, _ error: Error?) -> Result<WalkingRoute, RouteFailure> {
        if let error { return .failure(failure(for: error)) }
        guard let route = response?.routes.first else { return .failure(.noRoute) }
        let polyline = route.polyline
        let points = polyline.points()
        let coordinates = (0..<polyline.pointCount).map { Coordinate(points[$0].coordinate) }
        guard coordinates.count >= 2 else { return .failure(.noRoute) }
        return .success(WalkingRoute(coordinates: coordinates, distanceMeters: route.distance,
                                     expectedTravelTime: route.expectedTravelTime))
    }

    private nonisolated static func failure(for error: Error) -> RouteFailure {
        if let mapKitError = error as? MKError {
            switch mapKitError.code {
            case .directionsNotFound, .placemarkNotFound: return .noRoute
            case .loadingThrottled: return .throttled
            case .serverFailure: return .network
            default: return .unknown
            }
        }
        if (error as NSError).domain == NSURLErrorDomain { return .network }
        return .unknown
    }
}

/// One in-flight `MKDirections` request. Resumes its caller exactly once: route, error, cancellation or deadline.
/// `MKDirections` is touched only on the main actor; the continuation is guarded by a mutex.
private nonisolated final class DirectionsCall: @unchecked Sendable {
    private typealias Outcome = Result<WalkingRoute, RouteFailure>

    private let directions: MKDirections
    private let continuation = Mutex<CheckedContinuation<Outcome, Never>?>(nil)

    init(_ directions: MKDirections) {
        self.directions = directions
    }

    @MainActor
    func run(deadlineSeconds: Int) async -> Result<WalkingRoute, RouteFailure> {
        await withTaskCancellationHandler {
            await withCheckedContinuation { (continuation: CheckedContinuation<Outcome, Never>) in
                self.continuation.withLock { $0 = continuation }
                guard !Task.isCancelled else {
                    finish(.failure(.cancelled))
                    return
                }
                directions.calculate { response, error in
                    self.finish(MapKitRoutingService.outcome(response, error))
                }
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(deadlineSeconds))
                    guard self.finish(.failure(.network)) else { return }
                    self.directions.cancel()
                }
            }
        } onCancel: {
            guard self.finish(.failure(.cancelled)) else { return }
            Task { @MainActor in self.directions.cancel() }
        }
    }

    /// True for the call that actually resumed the caller.
    @discardableResult
    private func finish(_ outcome: Outcome) -> Bool {
        let pending = continuation.withLock { continuation in
            defer { continuation = nil }
            return continuation
        }
        pending?.resume(returning: outcome)
        return pending != nil
    }
}
