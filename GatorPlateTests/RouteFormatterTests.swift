import Foundation
import Testing
@testable import GatorPlate

struct RouteFormatterTests {
    private let us = Locale(identifier: "en_US")
    private let metric = Locale(identifier: "en_GB")

    @Test func minutesRoundUp() {
        #expect(RouteFormatter.minutes(for: 61) == 2)
        #expect(RouteFormatter.minutes(for: 60) == 1)
        #expect(RouteFormatter.minutes(for: 240) == 4)
        #expect(RouteFormatter.minutes(for: 241) == 5)
    }

    @Test func minutesNeverShowLessThanOne() {
        #expect(RouteFormatter.minutes(for: 0) == 1)
        #expect(RouteFormatter.minutes(for: 5) == 1)
    }

    @Test func summaryJoinsMinutesAndDistance() {
        let text = RouteFormatter.summary(distanceMeters: 350, travelTime: 270, locale: us)
        #expect(text.hasPrefix("5 min · "))
        #expect(text.hasSuffix("ft") || text.hasSuffix("mi"))
    }

    @Test func metricLocalesGetMeters() {
        let text = RouteFormatter.distance(meters: 350, locale: metric)
        #expect(text.contains("m"))
        #expect(!text.contains("ft"))
    }

    @Test func spokenSummaryIsPluralAware() {
        #expect(RouteFormatter.spokenSummary(distanceMeters: 80, travelTime: 30, locale: us).hasPrefix("1 minute walk"))
        #expect(RouteFormatter.spokenSummary(distanceMeters: 800, travelTime: 600, locale: us).hasPrefix("10 minutes walk"))
    }
}
