import CoreLocation
import MapKit
import OSLog

/// `MKDirections` walking routes and the Apple Maps hand-off. Only plain values leave this file.
nonisolated struct MapKitRoutingService: RoutingService {
    /// `MKDirections` is not `Sendable`; `cancel()` is safe to call from any thread, so the box only exists
    /// to let the cancellation handler reach it.
    private final class DirectionsBox: @unchecked Sendable {
        let directions: MKDirections
        init(_ directions: MKDirections) { self.directions = directions }
    }

    func walkingRoute(from: Coordinate, to: Coordinate) async throws -> WalkingRoute {
        let request = MKDirections.Request()
        request.source = Self.mapItem(at: from)
        request.destination = Self.mapItem(at: to)
        request.transportType = .walking
        let box = DirectionsBox(MKDirections(request: request))

        do {
            let response = try await withTaskCancellationHandler {
                try await box.directions.calculate()
            } onCancel: {
                box.directions.cancel()
            }
            try Task.checkCancellation()
            guard let route = response.routes.first else { throw RoutingError.noRoute }
            return WalkingRoute(
                coordinates: Self.coordinates(of: route.polyline),
                distanceMeters: route.distance,
                travelTime: route.expectedTravelTime
            )
        } catch let error as RoutingError {
            throw error
        } catch {
            if Task.isCancelled { throw CancellationError() }
            Logger.app.error("Walking route failed")
            throw Self.map(error)
        }
    }

    @MainActor
    func openInAppleMaps(name: String, coordinate: Coordinate) -> Bool {
        let item = Self.mapItem(at: coordinate)
        item.name = name
        return item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking])
    }

    // MARK: Helpers

    private static func mapItem(at coordinate: Coordinate) -> MKMapItem {
        MKMapItem(location: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude), address: nil)
    }

    private static func coordinates(of polyline: MKPolyline) -> [Coordinate] {
        var points = [CLLocationCoordinate2D](repeating: CLLocationCoordinate2D(), count: polyline.pointCount)
        polyline.getCoordinates(&points, range: NSRange(location: 0, length: polyline.pointCount))
        return points.map(Coordinate.init)
    }

    static func map(_ error: any Error) -> RoutingError {
        if let mapKitError = error as? MKError, mapKitError.code == .directionsNotFound {
            return .noRoute
        }
        return .network
    }
}
