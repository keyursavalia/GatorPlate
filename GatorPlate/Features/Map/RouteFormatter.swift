import Foundation

/// "4 min · 350 m". Minutes round up and never show less than 1; distance follows the user's units.
nonisolated enum RouteFormatter {
    static func minutes(for travelTime: TimeInterval) -> Int {
        max(1, Int((travelTime / 60).rounded(.up)))
    }

    static func summary(distanceMeters: Double, travelTime: TimeInterval, locale: Locale = .current) -> String {
        "\(minutes(for: travelTime)) min · \(distance(meters: distanceMeters, locale: locale))"
    }

    static func distance(meters: Double, locale: Locale = .current) -> String {
        Measurement(value: meters, unit: UnitLength.meters)
            .formatted(.measurement(width: .abbreviated, usage: .road).locale(locale))
    }

    static func spokenSummary(distanceMeters: Double, travelTime: TimeInterval, locale: Locale = .current) -> String {
        let minutes = minutes(for: travelTime)
        let distance = Measurement(value: distanceMeters, unit: UnitLength.meters)
            .formatted(.measurement(width: .wide, usage: .road).locale(locale))
        return "\(minutes) \(minutes == 1 ? "minute" : "minutes") walk, \(distance)"
    }
}
