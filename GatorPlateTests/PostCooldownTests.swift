import Foundation
import Testing
@testable import GatorPlate

struct PostCooldownTests {
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func allowedBeforeAnyPost() {
        #expect(PostCooldown().remainingSeconds(now: start) == 0)
    }

    @Test func blockedRightAfterAPost() {
        let cooldown = PostCooldown()
        cooldown.recordPublish(at: start)
        #expect(cooldown.remainingSeconds(now: start) == 60)
        #expect(cooldown.remainingSeconds(now: start.addingTimeInterval(1)) == 59)
    }

    @Test func blockedAtFiftyNineSecondsAllowedAtSixty() {
        let cooldown = PostCooldown()
        cooldown.recordPublish(at: start)
        #expect(cooldown.remainingSeconds(now: start.addingTimeInterval(59)) == 1)
        #expect(cooldown.remainingSeconds(now: start.addingTimeInterval(60)) == 0)
        #expect(cooldown.remainingSeconds(now: start.addingTimeInterval(600)) == 0)
    }

    @Test func partialSecondsRoundUp() {
        let cooldown = PostCooldown()
        cooldown.recordPublish(at: start)
        #expect(cooldown.remainingSeconds(now: start.addingTimeInterval(59.4)) == 1)
    }
}
