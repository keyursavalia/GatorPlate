import Foundation

/// Distances and walking times in the user's locale, shared by the map card and the feed.
nonisolated enum DistanceText {
    /// "350 ft" / "110 m".
    static func distance(meters: Double) -> String {
        Measurement(value: meters, unit: UnitLength.meters)
            .formatted(.measurement(width: .abbreviated, usage: .road))
    }

    /// "350 ft away", or nil without a location fix.
    static func away(meters: Double?) -> String? {
        meters.map { "\(distance(meters: $0)) away" }
    }

    /// Straight-line walking estimate at about 80 m a minute ("4 min walk"). Apple Maps gives the real route.
    static func walkMinutes(meters: Double) -> Int {
        max(1, Int((meters / walkingMetersPerMinute).rounded(.up)))
    }

    static let walkingMetersPerMinute = 80.0
}
