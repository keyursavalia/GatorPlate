import Testing
@testable import GatorPlate

struct AppConfigTests {
    @Test func allowedEmailDomainsAreSFSU() {
        #expect(AppConfig.allowedEmailDomains == ["sfsu.edu", "mail.sfsu.edu"])
    }

    @Test func defaultDurationIsOfferedAndWithinMax() {
        #expect(AppConfig.postDurationOptionsMinutes.contains(AppConfig.defaultPostDurationMinutes))
        #expect(AppConfig.defaultPostDurationMinutes <= AppConfig.maxPostDurationMinutes)
    }

    @Test func noDurationOptionExceedsMax() {
        #expect(AppConfig.postDurationOptionsMinutes.allSatisfy { $0 <= AppConfig.maxPostDurationMinutes })
    }

    @Test func defaultDurationMatchesGatorGrubRule() {
        #expect(AppConfig.defaultPostDurationMinutes == 30)
        #expect(AppConfig.maxPostDurationMinutes == 60)
    }
}
