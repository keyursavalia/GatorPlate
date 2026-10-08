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

    /// Whole minutes, rounded up, at least 1: "6 min walk".
    static func walk(seconds: TimeInterval) -> String {
        "\(walkMinutes(seconds: seconds)) min walk"
    }

    static func walkMinutes(seconds: TimeInterval) -> Int {
        max(1, Int((seconds / 60).rounded(.up)))
    }
}
