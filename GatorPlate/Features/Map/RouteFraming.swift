import MapKit

/// Camera rect for a walking route: padded on every side, with extra room at the bottom for the sheet.
nonisolated enum RouteFraming {
    /// Fraction of the route's size added on the top, left and right.
    static let sidePadding = 0.25
    /// Extra fraction below the route, where the bottom card covers the map.
    static let sheetPadding = 0.9
    /// Short routes still show some context around them.
    static let minimumSideMeters = 250.0

    static func rect(for coordinates: [Coordinate]) -> MKMapRect {
        var bounds = MKMapRect.null
        for coordinate in coordinates {
            let point = MKMapPoint(coordinate.clLocationCoordinate)
            bounds = bounds.union(MKMapRect(origin: point, size: MKMapSize(width: 0, height: 0)))
        }
        guard !bounds.isNull else { return bounds }

        let pointsPerMeter = MKMapPointsPerMeterAtLatitude(bounds.origin.coordinate.latitude)
        let minimumSide = minimumSideMeters * pointsPerMeter
        let width = max(bounds.width, minimumSide)
        let height = max(bounds.height, minimumSide)
        let center = MKMapPoint(x: bounds.midX, y: bounds.midY)

        // Map points grow southward, so the sheet padding goes on the max-y side.
        let originX = center.x - width / 2 - width * sidePadding
        let originY = center.y - height / 2 - height * sidePadding
        return MKMapRect(x: originX, y: originY,
                         width: width * (1 + 2 * sidePadding),
                         height: height * (1 + sidePadding + sheetPadding))
    }
}
