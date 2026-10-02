import Foundation
import Testing
@testable import GatorPlate

struct PostValidationTests {
    /// A draft that passes every rule.
    private func validDraft() -> PostDraft {
        var draft = PostDraft()
        draft.title = "FREE: Pizza - SSB 201 - until 8:35 PM"
        draft.description = String(repeating: "a", count: 120)
        draft.items = [DraftItem(name: "Pizza", dietary: .vegetarian)]
        draft.buildingId = "student-services"
        draft.roomDetail = "Room 201"
        draft.attested = true
        return draft
    }

    private func fields(_ draft: PostDraft, blockingOnly: Bool = true) -> Set<PostField> {
        let issues = PostValidation.issues(for: draft)
        return Set((blockingOnly ? PostValidation.blocking(issues) : issues).map(\.field))
    }

    @Test func validDraftHasNoIssues() {
        #expect(PostValidation.issues(for: validDraft()).isEmpty)
    }

    @Test func emptyDraftBlocksEveryRequiredField() {
        #expect(fields(PostDraft()) == [.title, .description, .items, .location, .roomDetail, .attestation])
    }

    @Test(arguments: [
        ("", true), ("   ", true), ("x", false),
        (String(repeating: "a", count: 120), false), (String(repeating: "a", count: 121), true)
    ])
    func titleRules(title: String, blocked: Bool) {
        var draft = validDraft()
        draft.title = title
        #expect(fields(draft).contains(.title) == blocked)
    }

    /// 1 to 99 characters is only a warning; empty and over 150 block.
    @Test(arguments: [(0, true), (1, false), (99, false), (100, false), (150, false), (151, true)])
    func descriptionLengthBlocksOnlyOutsideTheHardLimits(length: Int, blocked: Bool) {
        var draft = validDraft()
        draft.description = String(repeating: "a", count: length)
        #expect(fields(draft).contains(.description) == blocked)
    }

    @Test func shortDescriptionWarnsButDoesNotBlock() {
        var draft = validDraft()
        draft.description = "Pizza"
        let issues = PostValidation.issues(for: draft).filter { $0.field == .description }
        #expect(issues.count == 1)
        #expect(issues.first?.isBlocking == false)
    }

    @Test func descriptionIsTrimmedBeforeCounting() {
        var draft = validDraft()
        draft.description = "  \n  " + String(repeating: "a", count: 150) + "   "
        #expect(!fields(draft).contains(.description))
    }

    @Test func itemRules() {
        var draft = validDraft()
        draft.items = []
        #expect(fields(draft).contains(.items))
        draft.items = [DraftItem(name: "   ")]
        #expect(fields(draft).contains(.items))
        draft.items = [DraftItem(name: String(repeating: "a", count: 61))]
        #expect(fields(draft).contains(.items))
        draft.items = (0..<13).map { DraftItem(name: "Item \($0)") }
        #expect(fields(draft).contains(.items))
        draft.items = (0..<12).map { DraftItem(name: "Item \($0)") }
        #expect(!fields(draft).contains(.items))
    }

    @Test func blankItemRowsAreIgnoredNotErrors() {
        var draft = validDraft()
        draft.items.append(DraftItem(name: "  "))
        #expect(PostValidation.issues(for: draft).isEmpty)
    }

    @Test(arguments: [(nil, false), (0, true), (1, false), (500, false), (501, true)] as [(Int?, Bool)])
    func servingsRules(servings: Int?, blocked: Bool) {
        var draft = validDraft()
        draft.servings = servings
        #expect(fields(draft).contains(.servings) == blocked)
    }

    @Test func cautionRules() {
        var draft = validDraft()
        draft.cautions = Array(repeating: "Keep cold.", count: 5)
        #expect(!fields(draft).contains(.cautions))
        draft.cautions = Array(repeating: "Keep cold.", count: 6)
        #expect(fields(draft).contains(.cautions))
        draft.cautions = [String(repeating: "a", count: 121)]
        #expect(fields(draft).contains(.cautions))
    }

    @Test func roomDetailIsRequiredAndCapped() {
        var draft = validDraft()
        draft.roomDetail = "  "
        #expect(fields(draft).contains(.roomDetail))
        draft.roomDetail = String(repeating: "a", count: 81)
        #expect(fields(draft).contains(.roomDetail))
        draft.roomDetail = String(repeating: "a", count: 80)
        #expect(!fields(draft).contains(.roomDetail))
    }

    @Test func attestationIsRequired() {
        var draft = validDraft()
        draft.attested = false
        #expect(fields(draft) == [.attestation])
    }

    @Test(arguments: [15, 30, 45, 60])
    func offeredDurationsAreValid(minutes: Int) {
        var draft = validDraft()
        draft.durationMinutes = minutes
        #expect(!fields(draft).contains(.duration))
    }

    @Test(arguments: [0, 10, 20, 75, 90, 120])
    func otherDurationsAreInvalid(minutes: Int) {
        var draft = validDraft()
        draft.durationMinutes = minutes
        #expect(fields(draft).contains(.duration))
    }

    @Test func missingLocationExplainsWhat() {
        var draft = validDraft()
        draft.buildingId = nil
        let message = PostValidation.issues(for: draft).first { $0.field == .location }?.message
        #expect(message == "Choose the building where the food is.")
    }

    @Test func offCampusPinIsRejectedWithItsOwnMessage() {
        var draft = validDraft()
        draft.buildingId = nil
        draft.pin = Coordinate(latitude: 37.3349, longitude: -122.0090)
        let message = PostValidation.issues(for: draft).first { $0.field == .location }?.message
        #expect(message?.contains("off campus") == true)
    }

    @Test func onCampusPinIsAccepted() {
        var draft = validDraft()
        draft.buildingId = nil
        draft.pin = SFSUCampus.center
        #expect(!fields(draft).contains(.location))
        #expect(draft.location?.buildingId == AppConfig.customPinBuildingId)
    }

    @Test func unknownBuildingIdIsRejected() {
        var draft = validDraft()
        draft.buildingId = "not-a-building"
        #expect(fields(draft).contains(.location))
    }

    @Test func everyCatalogBuildingIsAValidLocation() {
        for building in CampusBuildings.all {
            var draft = validDraft()
            draft.buildingId = building.id
            #expect(draft.location?.coordinate == building.coordinate)
            #expect(SFSUCampus.contains(building.coordinate))
        }
    }

    @Test func controlCharactersAndNewlinesAreFlattened() {
        #expect(PostText.line("  Pizza\n\nand\tsalad\u{0007}  ") == "Pizza and salad")
    }
}
