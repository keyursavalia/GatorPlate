import MapKit

/// Camera framing for a route. The Map's `bounds:` still clamps whatever is requested, so the campus lock holds.
nonisolated enum RouteCamera {
    private static let sidePaddingFraction = 0.3
    private static let topPaddingFraction = 0.3
    /// Extra room below the route for the bottom sheet.
    private static let bottomPaddingFraction = 1.0
    private static let minimumSideMeters = 200.0

    static func rect(for coordinates: [Coordinate]) -> MKMapRect? {
        guard let first = coordinates.first else { return nil }
        let origin = MKMapPoint(first.clCoordinate)
        var rect = MKMapRect(origin: origin, size: MKMapSize(width: 0, height: 0))
        for coordinate in coordinates.dropFirst() {
            rect = rect.union(MKMapRect(origin: MKMapPoint(coordinate.clCoordinate), size: MKMapSize(width: 0, height: 0)))
        }

        let minimumSide = minimumSideMeters * MKMapPointsPerMeterAtLatitude(first.latitude)
        let width = max(rect.size.width, minimumSide)
        let height = max(rect.size.height, minimumSide)
        let centerX = rect.midX
        let centerY = rect.midY
        let side = width * sidePaddingFraction
        return MKMapRect(
            x: centerX - width / 2 - side,
            y: centerY - height / 2 - height * topPaddingFraction,
            width: width + side * 2,
            height: height * (1 + topPaddingFraction + bottomPaddingFraction)
        )
    }
}
