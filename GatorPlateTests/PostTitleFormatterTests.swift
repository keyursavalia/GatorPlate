import Foundation
import Testing
@testable import GatorPlate

struct PostTitleFormatterTests {
    private let locale = Locale(identifier: "en_US")
    private let zone = TimeZone(identifier: "America/Los_Angeles") ?? .gmt
    /// 2027-01-15 20:35 in Los Angeles.
    private var expires: Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        return calendar.date(from: DateComponents(year: 2027, month: 1, day: 15, hour: 20, minute: 35)) ?? Date()
    }

    private func title(items: [String], place: String? = "SSB", room: String = "201") -> String? {
        PostTitleFormatter.suggestion(
            items: items, place: place, roomDetail: room, expiresAt: expires, locale: locale, timeZone: zone
        )
    }

    @Test func followsTheGatorGrubFormat() {
        let result = title(items: ["Pizza"])
        #expect(result?.hasPrefix("FREE: Pizza - SSB 201 - until 8:35") == true)
        #expect(result?.hasSuffix("PM") == true)
    }

    @Test func manyItemsAreSummarized() {
        #expect(title(items: ["Pizza", "Salad"])?.hasPrefix("FREE: Pizza and more - ") == true)
    }

    @Test func noItemsMeansNoSuggestion() {
        #expect(title(items: []) == nil)
        #expect(title(items: ["  "]) == nil)
    }

    @Test func missingPlaceLeavesOutTheLocationPart() {
        let result = title(items: ["Pizza"], place: nil, room: "")
        #expect(result?.hasPrefix("FREE: Pizza - until ") == true)
    }

    @Test func roomOnlyStillAppears() {
        #expect(title(items: ["Pizza"], place: nil, room: "Room 5")?.hasPrefix("FREE: Pizza - Room 5 - until ") == true)
    }

    @Test func longFoodNamesAreTruncatedToFitTheLimit() {
        let result = title(items: [String(repeating: "Delicious ", count: 30)])
        #expect((result?.count ?? 0) <= AppConfig.maxTitleLength)
        #expect(result?.contains("…") == true)
        #expect(result?.hasSuffix("PM") == true)
    }
}
