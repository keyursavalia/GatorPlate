import Foundation
import Observation
import OSLog

/// State of the Review form. Lives in the view's `@State`, so it survives backgrounding in memory only;
/// drafts are never written to disk.
@Observable @MainActor
final class ReviewViewModel {
    enum Phase: Equatable {
        case editing
        case publishing
        case published(FoodPost)
    }

    private(set) var draft: PostDraft
    private(set) var phase: Phase = .editing
    /// Set when a publish fails; the draft stays as it was so the poster can retry.
    private(set) var errorMessage: String?
    /// Shown after publishing without the photo (too large to store).
    private(set) var photoDropped = false
    /// True after the first Publish tap, so every inline error shows from then on.
    private(set) var showAllErrors = false
    private(set) var failedOnce = false

    /// True while the title follows the suggestion (manual path). Typing in the title turns it off.
    private(set) var titleIsAuto: Bool
    private(set) var touched: Set<PostField> = []

    let photo: CapturedPhoto?
    let aiBaseline: FoodAnalysisResult?

    private let profile: UserProfile
    private let posts: any PostService
    private let location: any LocationProviding
    private let cooldown: PostCooldown
    private let now: @Sendable () -> Date
    /// Stable across retries so a retry overwrites instead of duplicating.
    private let postID = UUID().uuidString

    init(
        profile: UserProfile,
        analysis: FoodAnalysisResult?,
        photo: CapturedPhoto?,
        posts: any PostService,
        location: any LocationProviding,
        cooldown: PostCooldown,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.profile = profile
        self.aiBaseline = analysis
        self.photo = photo
        self.posts = posts
        self.location = location
        self.cooldown = cooldown
        self.now = now
        self.draft = analysis.map(PostDraft.init(analysis:)) ?? PostDraft()
        self.titleIsAuto = analysis == nil
    }

    // MARK: Derived

    var isAIDraft: Bool { aiBaseline != nil }
    var editedAfterAI: Bool { draft.editedAfterAI(comparedTo: aiBaseline) }
    var allIssues: [PostValidation.Issue] { PostValidation.issues(for: draft) }
    var blockingIssues: [PostValidation.Issue] { PostValidation.blocking(allIssues) }
    var canPublish: Bool { blockingIssues.isEmpty && phase == .editing }
    var isPublishing: Bool { phase == .publishing }

    /// Issues worth showing now: all of them after a Publish tap, otherwise only for fields the poster has touched.
    func issues(for field: PostField) -> [PostValidation.Issue] {
        guard showAllErrors || touched.contains(field) else { return [] }
        return allIssues.filter { $0.field == field }
    }

    /// Short reasons under the disabled button.
    var blockingHints: [String] { blockingIssues.map(\.message) }

    func expiresAt() -> Date { draft.expiresAt(from: now()) }

    var suggestedTitle: String? {
        PostTitleFormatter.suggestion(
            items: draft.cleanedItems.map(\.name),
            place: draft.location?.shortName,
            roomDetail: draft.roomDetail,
            expiresAt: expiresAt()
        )
    }

    /// True when the AI title is still in place and a different suggestion is available.
    var canOfferSuggestedTitle: Bool {
        guard let suggestedTitle else { return false }
        return !titleIsAuto && PostText.line(draft.title) != suggestedTitle
    }

    enum AIField { case title, description, items, allergens, cautions, servings }

    /// The badge shows only while the field still matches what the AI wrote.
    func showsAIBadge(_ field: AIField) -> Bool {
        guard let aiBaseline else { return false }
        let base = PostDraft(analysis: aiBaseline).aiFields
        let current = draft.aiFields
        switch field {
        case .title: return base.title == current.title
        case .description: return base.description == current.description
        case .items: return base.items == current.items
        case .allergens: return base.allergens == current.allergens
        case .cautions: return base.cautions == current.cautions
        case .servings: return base.servings == current.servings
        }
    }

    // MARK: Edits

    func touch(_ field: PostField) { touched.insert(field) }

    func setTitle(_ value: String) {
        draft.title = value
        titleIsAuto = false
        touched.insert(.title)
    }

    func applySuggestedTitle() {
        guard let suggestedTitle else { return }
        draft.title = suggestedTitle
        titleIsAuto = true
    }

    func setDescription(_ value: String) {
        draft.description = String(value.prefix(AppConfig.maxDescriptionLength))
        touched.insert(.description)
    }

    func addItem() {
        guard draft.items.count < AppConfig.maxFoodItems else { return }
        draft.items.append(DraftItem(name: ""))
        refreshAutoTitle()
    }

    func removeItem(id: UUID) {
        draft.items.removeAll { $0.id == id }
        touched.insert(.items)
        refreshAutoTitle()
    }

    func renameItem(id: UUID, to name: String) {
        guard let index = draft.items.firstIndex(where: { $0.id == id }) else { return }
        draft.items[index].name = String(name.prefix(AppConfig.maxItemNameLength))
        touched.insert(.items)
        refreshAutoTitle()
    }

    func setDietary(_ dietary: DietaryClass, forItem id: UUID) {
        guard let index = draft.items.firstIndex(where: { $0.id == id }) else { return }
        draft.items[index].dietary = dietary
    }

    func toggleAllergen(_ allergen: Allergen) {
        if draft.allergens.contains(allergen) {
            draft.allergens.remove(allergen)
        } else {
            draft.allergens.insert(allergen)
            draft.allergensUnverified = false
        }
    }

    func setCautions(_ cautions: [String]) {
        draft.cautions = cautions
        touched.insert(.cautions)
    }

    func addCaution() {
        guard draft.cautions.count < AppConfig.maxCautions else { return }
        draft.cautions.append("")
    }

    func removeCaution(at index: Int) {
        guard draft.cautions.indices.contains(index) else { return }
        draft.cautions.remove(at: index)
    }

    func setServings(_ servings: Int?) {
        draft.servings = servings
    }

    func selectBuilding(_ id: String) {
        guard CampusBuildings.building(id: id) != nil else { return }
        draft.buildingId = id
        draft.pin = nil
        touched.insert(.location)
        refreshAutoTitle()
    }

    /// Returns false (and keeps the old location) if the pin is outside the campus region.
    @discardableResult
    func dropPin(_ coordinate: Coordinate) -> Bool {
        touched.insert(.location)
        guard SFSUCampus.contains(coordinate) else { return false }
        draft.pin = coordinate
        draft.buildingId = nil
        refreshAutoTitle()
        return true
    }

    func setRoomDetail(_ value: String) {
        draft.roomDetail = String(value.prefix(AppConfig.maxRoomDetailLength))
        touched.insert(.roomDetail)
        refreshAutoTitle()
    }

    func setDuration(_ minutes: Int) {
        guard AppConfig.selectableDurationOptionsMinutes.contains(minutes),
              minutes <= AppConfig.maxPostDurationMinutes else { return }
        draft.durationMinutes = minutes
        refreshAutoTitle()
    }

    func setAttested(_ value: Bool) {
        draft.attested = value
        touched.insert(.attestation)
    }

    private func refreshAutoTitle() {
        guard titleIsAuto else { return }
        draft.title = suggestedTitle ?? ""
    }

    // MARK: Default location

    /// Pre-selects the nearest building when the poster is on campus. Never prompts, never blocks.
    func selectNearestBuildingIfOnCampus() async {
        guard draft.buildingId == nil, draft.pin == nil else { return }
        guard let here = try? await location.currentLocation(), SFSUCampus.contains(here) else { return }
        // The poster may have chosen while the fix was in flight.
        guard draft.buildingId == nil, draft.pin == nil else { return }
        if let nearest = CampusBuildings.all.min(by: { $0.coordinate.distance(to: here) < $1.coordinate.distance(to: here) }) {
            selectBuilding(nearest.id)
        }
    }

    // MARK: Publish

    func publish() async {
        guard phase == .editing else { return }
        showAllErrors = true
        errorMessage = nil

        let wait = cooldown.remainingSeconds(now: now())
        guard wait == 0 else {
            errorMessage = "You just posted. You can post again in \(wait) second\(wait == 1 ? "" : "s")."
            return
        }
        let publishTime = now()
        guard blockingIssues.isEmpty,
              let post = draft.makePost(
                  id: postID, author: profile, now: publishTime, hasPhoto: photo != nil,
                  aiGenerated: isAIDraft, editedAfterAI: editedAfterAI
              )
        else { return }

        phase = .publishing
        let jpeg = await cappedPhoto()
        photoDropped = photo != nil && jpeg == nil
        do {
            let stored = try await posts.publish(post, imageJPEG: jpeg)
            if photo != nil, !stored.hasPhoto { photoDropped = true }
            cooldown.recordPublish(at: publishTime)
            phase = .published(stored)
        } catch {
            failedOnce = true
            phase = .editing
            errorMessage = Self.message(for: error)
            Logger.app.error("Publish failed")
        }
    }

    private func cappedPhoto() async -> Data? {
        guard let photo else { return nil }
        return await ImagePreprocessor.fittingCapInBackground(photo.jpegData)
    }

    static func message(for error: any Error) -> String {
        switch error as? AppError {
        case .network:
            "You're offline. Your post is still here. Reconnect and tap Try again."
        case .permissionDenied, .unauthorized:
            "You don't have permission to post. Sign out and back in, then try again."
        case .validation(let message):
            message
        default:
            "Couldn't publish your post. Your draft is still here. Try again."
        }
    }
}
