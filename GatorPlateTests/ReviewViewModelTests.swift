import Foundation
import Testing
@testable import GatorPlate

@MainActor
struct ReviewViewModelTests {
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    private func makeModel(
        analysis: FoodAnalysisResult? = SampleData.analysisCautious,
        photo: CapturedPhoto? = nil,
        posts: MockPostService = MockPostService(posts: []),
        location: MockLocationProvider = MockLocationProvider(status: .denied, coordinate: nil),
        cooldown: PostCooldown = PostCooldown(),
        profile: UserProfile = SampleData.profile
    ) -> ReviewViewModel {
        let start = start
        return ReviewViewModel(
            profile: profile, analysis: analysis, photo: photo, posts: posts, location: location,
            cooldown: cooldown, now: { start }
        )
    }

    /// Fills the required fields the AI cannot know.
    private func complete(_ model: ReviewViewModel) {
        model.selectBuilding("student-services")
        model.setRoomDetail("Room 201")
        model.setAttested(true)
    }

    // MARK: Publish enabled matrix

    @Test func aiDraftNeedsLocationRoomAndAttestation() {
        let model = makeModel()
        #expect(!model.canPublish)
        #expect(Set(model.blockingIssues.map(\.field)) == [.location, .roomDetail, .attestation])
        model.selectBuilding("library")
        model.setRoomDetail("Lobby")
        #expect(!model.canPublish)
        model.setAttested(true)
        #expect(model.canPublish)
    }

    @Test func manualPathNeedsEverything() {
        let model = makeModel(analysis: nil)
        #expect(Set(model.blockingIssues.map(\.field)) == [.title, .description, .items, .location, .roomDetail, .attestation])
        #expect(!model.isAIDraft)
    }

    @Test func hintsExplainWhatIsMissing() {
        let model = makeModel()
        #expect(model.blockingHints.contains("Choose the building where the food is."))
        #expect(model.blockingHints.contains("Confirm the food safety statement to post."))
    }

    @Test func errorsAreHiddenUntilTouched() {
        let model = makeModel()
        #expect(model.issues(for: .roomDetail).isEmpty)
        model.touch(.roomDetail)
        #expect(!model.issues(for: .roomDetail).isEmpty)
    }

    // MARK: Publish

    @Test func publishSendsTheApprovedPost() async throws {
        let posts = MockPostService(posts: [])
        let model = makeModel(posts: posts)
        complete(model)
        await model.publish()

        guard case .published(let post) = model.phase else {
            Issue.record("Expected published, got \(model.phase)")
            return
        }
        #expect(post.status == .active)
        #expect(post.aiGenerated)
        #expect(!post.editedAfterAI)
        #expect(post.expiresAt == start.addingTimeInterval(1800))
        #expect(post.locationDetail == "Room 201")
        #expect(await posts.allPosts().map(\.id) == [post.id])
    }

    @Test func editingAnAIFieldSetsEditedAfterAI() async {
        let model = makeModel()
        complete(model)
        model.setDescription("Different words about the food")
        await model.publish()
        guard case .published(let post) = model.phase else {
            Issue.record("Expected published")
            return
        }
        #expect(post.editedAfterAI)
    }

    @Test func manualPostWithoutPhotoOrAI() async throws {
        let posts = MockPostService(posts: [])
        let model = makeModel(analysis: nil, posts: posts)
        model.setTitle("FREE: Cookies - SSB 201")
        model.setDescription("Chocolate chip cookies from the club meeting, plenty left on the table by the door.")
        model.addItem()
        let itemID = try #require(model.draft.items.first?.id)
        model.renameItem(id: itemID, to: "Cookies")
        complete(model)
        await model.publish()

        guard case .published(let post) = model.phase else {
            Issue.record("Expected published")
            return
        }
        #expect(!post.aiGenerated && !post.editedAfterAI && !post.hasPhoto)
        #expect(await posts.publishedImages.isEmpty)
    }

    @Test func photoIsPassedToTheService() async throws {
        let posts = MockPostService(posts: [])
        let photo = try ImagePreprocessor.process(data: PlaceholderImage.jpegData())
        let model = makeModel(photo: photo, posts: posts)
        complete(model)
        await model.publish()
        guard case .published(let post) = model.phase else {
            Issue.record("Expected published")
            return
        }
        #expect(post.hasPhoto)
        #expect(await posts.publishedImages[post.id] != nil)
        #expect(!model.photoDropped)
    }

    @Test func publishDoesNothingWhileInvalid() async {
        let posts = MockPostService(posts: [])
        let model = makeModel(posts: posts)
        await model.publish()
        #expect(model.phase == .editing)
        #expect(await posts.publishAttempts == 0)
        #expect(model.showAllErrors)
    }

    // MARK: Failure, retry, cooldown

    @Test func offlineKeepsTheDraftAndRetryReusesTheSameID() async {
        let posts = MockPostService(posts: [], publishError: .network)
        let model = makeModel(posts: posts)
        complete(model)
        model.setTitle("My edited title")
        await model.publish()

        #expect(model.phase == .editing)
        #expect(model.failedOnce)
        #expect(model.errorMessage?.contains("offline") == true)
        #expect(model.draft.title == "My edited title")
        #expect(model.draft.attested)

        await posts.setPublishError(nil)
        await model.publish()
        guard case .published(let post) = model.phase else {
            Issue.record("Expected published after retry")
            return
        }
        #expect(await posts.allPosts().count == 1)
        #expect(await posts.allPosts().first?.id == post.id)
        #expect(await posts.publishAttempts == 2)
    }

    @Test func cooldownBlocksASecondPostWithAFriendlyMessage() async {
        let cooldown = PostCooldown()
        cooldown.recordPublish(at: start.addingTimeInterval(-10))
        let posts = MockPostService(posts: [])
        let model = makeModel(posts: posts, cooldown: cooldown)
        complete(model)
        await model.publish()

        #expect(model.phase == .editing)
        #expect(model.errorMessage == "You just posted. You can post again in 50 seconds.")
        #expect(await posts.publishAttempts == 0)
    }

    @Test func successfulPublishStartsTheCooldown() async {
        let cooldown = PostCooldown()
        let model = makeModel(cooldown: cooldown)
        complete(model)
        await model.publish()
        #expect(cooldown.remainingSeconds(now: start) == AppConfig.postCooldownSeconds)
    }

    @Test func secondPublishWhilePublishingIsIgnored() async {
        let posts = MockPostService(posts: [], publishDelay: .milliseconds(100))
        let model = makeModel(posts: posts)
        complete(model)
        async let first: Void = model.publish()
        async let second: Void = model.publish()
        _ = await (first, second)
        #expect(await posts.publishAttempts == 1)
    }

    // MARK: Title behavior

    @Test func manualTitleFollowsLocationUntilTheUserTypes() {
        let model = makeModel(analysis: nil)
        model.addItem()
        if let id = model.draft.items.first?.id { model.renameItem(id: id, to: "Pizza") }
        model.selectBuilding("student-services")
        model.setRoomDetail("201")
        #expect(model.draft.title.hasPrefix("FREE: Pizza - SSB 201 - until "))

        model.setRoomDetail("305")
        #expect(model.draft.title.contains("SSB 305"))

        model.setTitle("My own title")
        model.setRoomDetail("400")
        #expect(model.draft.title == "My own title")
    }

    @Test func aiTitleIsKeptAndSuggestionIsOffered() {
        let model = makeModel()
        let aiTitle = model.draft.title
        model.selectBuilding("student-services")
        model.setRoomDetail("201")
        #expect(model.draft.title == aiTitle)
        #expect(model.canOfferSuggestedTitle)
        model.applySuggestedTitle()
        #expect(model.draft.title.hasPrefix("FREE: Veggie wrap and more - SSB 201"))
        #expect(!model.canOfferSuggestedTitle)
    }

    @Test func aiBadgeDisappearsOnceFieldIsEdited() {
        let model = makeModel()
        #expect(model.showsAIBadge(.title))
        model.setTitle("Changed")
        #expect(!model.showsAIBadge(.title))
        #expect(model.showsAIBadge(.description))
    }

    // MARK: Duration, pins, default location

    @Test func durationCannotExceedTheCap() {
        let model = makeModel()
        model.setDuration(90)
        #expect(model.draft.durationMinutes == 30)
        model.setDuration(60)
        #expect(model.draft.durationMinutes == 60)
        #expect(model.expiresAt() == start.addingTimeInterval(3600))
    }

    @Test func offCampusPinIsRefusedAndKeepsTheBuilding() {
        let model = makeModel()
        model.selectBuilding("library")
        #expect(!model.dropPin(Coordinate(latitude: 37.3349, longitude: -122.0090)))
        #expect(model.draft.buildingId == "library")
        #expect(model.dropPin(SFSUCampus.center))
        #expect(model.draft.buildingId == nil)
        #expect(model.draft.location?.buildingId == AppConfig.customPinBuildingId)
    }

    @Test func choosingABuildingClearsThePin() {
        let model = makeModel()
        model.dropPin(SFSUCampus.center)
        model.selectBuilding("library")
        #expect(model.draft.pin == nil)
    }

    @Test func descriptionIsCappedAtTheLimit() {
        let model = makeModel()
        model.setDescription(String(repeating: "a", count: 400))
        #expect(model.draft.description.count == AppConfig.maxDescriptionLength)
    }

    @Test func onCampusUserGetsTheNearestBuilding() async {
        let library = CampusBuildings.building(id: "library")
        let here = library?.coordinate ?? SFSUCampus.center
        let model = makeModel(location: MockLocationProvider(status: .authorizedFull, coordinate: here))
        await model.selectNearestBuildingIfOnCampus()
        #expect(model.draft.buildingId == "library")
    }

    @Test func offCampusOrDeniedLocationLeavesItEmpty() async {
        let off = makeModel(location: MockLocationProvider(
            status: .authorizedFull, coordinate: Coordinate(latitude: 37.3349, longitude: -122.0090)
        ))
        await off.selectNearestBuildingIfOnCampus()
        #expect(off.draft.buildingId == nil)

        let denied = makeModel()
        await denied.selectNearestBuildingIfOnCampus()
        #expect(denied.draft.buildingId == nil)
    }

    @Test func nearestBuildingDoesNotOverrideAnExistingChoice() async {
        let model = makeModel(location: MockLocationProvider(status: .authorizedFull, coordinate: SFSUCampus.center))
        model.selectBuilding("burk")
        await model.selectNearestBuildingIfOnCampus()
        #expect(model.draft.buildingId == "burk")
    }

    // MARK: Allergens and items

    @Test func pickingAnAllergenClearsTheUnverifiedFlag() {
        let model = makeModel(analysis: SampleData.analysisNoAllergens)
        #expect(model.draft.allergensUnverified)
        model.toggleAllergen(.peanuts)
        #expect(!model.draft.allergensUnverified)
        model.toggleAllergen(.peanuts)
        #expect(model.draft.allergens.isEmpty)
    }

    @Test func itemEditsAreByStableID() throws {
        let model = makeModel()
        let first = try #require(model.draft.items.first)
        model.removeItem(id: first.id)
        #expect(model.draft.items.count == 1)
        model.addItem()
        #expect(model.draft.items.count == 2)
        model.setDietary(.vegan, forItem: first.id)
        #expect(model.draft.items.count == 2)
    }

    @Test func errorMessagesAreFriendly() {
        #expect(ReviewViewModel.message(for: AppError.network).contains("offline"))
        #expect(ReviewViewModel.message(for: AppError.permissionDenied).contains("permission"))
        #expect(ReviewViewModel.message(for: AppError.unknown).contains("Try again"))
        #expect(ReviewViewModel.message(for: AppError.validation("Too big")) == "Too big")
    }
}
