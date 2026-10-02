import Foundation
import Testing
@testable import GatorPlate

struct PostDraftTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func filled(from analysis: FoodAnalysisResult = SampleData.analysisCautious) -> PostDraft {
        var draft = PostDraft(analysis: analysis)
        draft.buildingId = "student-services"
        draft.roomDetail = "Room 201"
        draft.attested = true
        return draft
    }

    // MARK: expiresAt and duration

    @Test(arguments: AppConfig.postDurationOptionsMinutes)
    func expiresAtIsNowPlusDuration(minutes: Int) {
        var draft = PostDraft()
        draft.durationMinutes = minutes
        #expect(draft.expiresAt(from: now) == now.addingTimeInterval(TimeInterval(minutes * 60)))
    }

    @Test func defaultDurationIsThirtyMinutes() {
        #expect(PostDraft().durationMinutes == 30)
        #expect(PostDraft().expiresAt(from: now) == now.addingTimeInterval(1800))
    }

    @Test func noOfferedDurationExceedsTheCap() {
        for minutes in AppConfig.postDurationOptionsMinutes {
            var draft = PostDraft()
            draft.durationMinutes = minutes
            #expect(draft.expiresAt(from: now).timeIntervalSince(now) <= TimeInterval(AppConfig.maxPostDurationMinutes * 60))
        }
    }

    // MARK: editedAfterAI

    @Test func untouchedAIDraftIsNotEdited() {
        #expect(!filled().editedAfterAI(comparedTo: SampleData.analysisCautious))
    }

    @Test func locationDurationAndAttestationAreNotAIFields() {
        var draft = filled()
        draft.durationMinutes = 45
        draft.roomDetail = "Lobby"
        draft.buildingId = "library"
        #expect(!draft.editedAfterAI(comparedTo: SampleData.analysisCautious))
    }

    @Test func editingEachAIFieldCountsAsEdited() {
        let baseline = SampleData.analysisCautious
        var title = filled(); title.title += "!"
        var description = filled(); description.description += " Extra."
        var item = filled(); item.items[0].name = "Chicken wrap"
        var dietary = filled(); dietary.items[0].dietary = .vegan
        var removed = filled(); removed.items.removeLast()
        var allergen = filled(); allergen.allergens.insert(.soy)
        var caution = filled(); caution.cautions = ["Something else"]
        var servings = filled(); servings.servings = 3
        for draft in [title, description, item, dietary, removed, allergen, caution, servings] {
            #expect(draft.editedAfterAI(comparedTo: baseline))
        }
    }

    @Test func whitespaceOnlyChangesAreNotEdits() {
        var draft = filled()
        draft.title = "  " + draft.title + "  "
        draft.description = draft.description.replacingOccurrences(of: " ", with: "  ")
        #expect(!draft.editedAfterAI(comparedTo: SampleData.analysisCautious))
    }

    @Test func editThenRevertIsNotEdited() {
        var draft = filled()
        let original = draft.title
        draft.title = "Something else"
        draft.title = original
        #expect(!draft.editedAfterAI(comparedTo: SampleData.analysisCautious))
    }

    @Test func manualPathIsNeverEditedAfterAI() {
        var draft = PostDraft()
        draft.title = "FREE: Cake"
        #expect(!draft.editedAfterAI(comparedTo: nil))
    }

    // MARK: Building the post

    @Test func makePostCarriesEveryApprovedField() throws {
        let author = SampleData.profile
        let post = try #require(filled().makePost(
            id: "p1", author: author, now: now, hasPhoto: true, aiGenerated: true, editedAfterAI: false
        ))
        #expect(post.id == "p1")
        #expect(post.authorUid == author.uid)
        #expect(post.authorName == author.displayName)
        #expect(post.status == .active)
        #expect(post.createdAt == now && post.updatedAt == now)
        #expect(post.expiresAt == now.addingTimeInterval(1800))
        #expect(post.buildingId == "student-services")
        #expect(post.locationName == "Student Services Building")
        #expect(post.locationDetail == "Room 201")
        #expect(post.hasPhoto && post.aiGenerated && !post.editedAfterAI)
        #expect(post.allergenWarnings == [.wheat, .sesame])
        #expect(post.estimatedServings == 10)
    }

    @Test func makePostRecomputesOverallDietaryFromItems() throws {
        var draft = filled(from: SampleData.analysis)
        draft.items = [
            DraftItem(name: "Rice", dietary: .vegan), DraftItem(name: "Chicken", dietary: .nonVegetarian)
        ]
        let post = try #require(draft.makePost(
            id: "p", author: SampleData.profile, now: now, hasPhoto: false, aiGenerated: true, editedAfterAI: true
        ))
        #expect(post.overallDietary == .mixed)
    }

    @Test func makePostNeedsALocation() {
        var draft = filled()
        draft.buildingId = nil
        #expect(draft.makePost(
            id: "p", author: SampleData.profile, now: now, hasPhoto: false, aiGenerated: false, editedAfterAI: false
        ) == nil)
    }

    @Test func orgNameOnlyForOrganizationAccounts() throws {
        var student = SampleData.profile
        student.orgName = "Leftover Club"
        var org = student
        org.accountType = .organization
        let studentPost = try #require(filled().makePost(
            id: "a", author: student, now: now, hasPhoto: false, aiGenerated: false, editedAfterAI: false
        ))
        let orgPost = try #require(filled().makePost(
            id: "b", author: org, now: now, hasPhoto: false, aiGenerated: false, editedAfterAI: false
        ))
        #expect(studentPost.orgName == nil)
        #expect(orgPost.orgName == "Leftover Club")
    }

    @Test func blankRowsAndNotesAreDropped() throws {
        var draft = filled()
        draft.items.append(DraftItem(name: "   "))
        draft.cautions = ["Keep cold.", "  "]
        let post = try #require(draft.makePost(
            id: "p", author: SampleData.profile, now: now, hasPhoto: false, aiGenerated: true, editedAfterAI: false
        ))
        #expect(post.items.count == 2)
        #expect(post.cautions == ["Keep cold."])
    }

    @Test func pinPostUsesTheCustomPinBuilding() throws {
        var draft = filled()
        draft.buildingId = nil
        draft.pin = SFSUCampus.center
        let post = try #require(draft.makePost(
            id: "p", author: SampleData.profile, now: now, hasPhoto: false, aiGenerated: false, editedAfterAI: false
        ))
        #expect(post.buildingId == AppConfig.customPinBuildingId)
        #expect(post.latitude == SFSUCampus.center.latitude)
    }
}
