import Testing
@testable import GatorPlate

@MainActor
struct TimeRemainingTests {
    private func display(_ seconds: Double) -> TimeRemainingPill.Display {
        TimeRemainingPill.Display(secondsLeft: seconds)
    }

    @Test func minutesRoundUp() {
        #expect(display(24 * 60).text == "24 min left")
        #expect(display(24 * 60 - 1).text == "24 min left")
        #expect(display(24 * 60 + 1).text == "25 min left")
    }

    @Test func under10MinutesIsAWarning() {
        #expect(!display(10 * 60).isWarning)
        #expect(display(10 * 60 - 1).isWarning)
        #expect(display(9 * 60 + 1).minutesLeft == 10)
    }

    @Test func under5MinutesIsEndingSoon() {
        #expect(!display(5 * 60).isEndingSoon)
        #expect(display(4 * 60 + 59).isEndingSoon)
        #expect(display(4 * 60 + 59).text == "Ending soon")
        #expect(display(4 * 60 + 59).spokenText == "Ending soon, 5 minutes left")
    }

    @Test func zeroAndNegativeAreExpired() {
        #expect(display(0).isExpired)
        #expect(display(-30).isExpired)
        #expect(display(-30).text == "Expired")
        #expect(display(-30).minutesLeft == 0)
    }
}
