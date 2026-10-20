import Foundation
import Observation
import OSLog

/// The Review composer (design system screen 4 step 3): AI draft or empty manual draft, edited by the user,
/// validated, then published with its photos. State lives in memory only.
@MainActor
@Observable
final class ReviewViewModel {
    enum PublishState: Equatable {
        case idle
        case publishing
        case failed(String)
        /// Seconds until the cooldown ends.
        case cooldown(Int)
    }

    var draft: PostDraft {
        didSet { refreshAutoTitle() }
    }
    private(set) var publishState: PublishState = .idle
    /// Starts from Settings > Show calorie estimates; "Hide" on Review only hides them here. Calories are still saved.
    var showCalories = UserDefaults.standard.object(forKey: ReviewViewModel.showCaloriesKey) as? Bool ?? true
    /// Nil on the manual path.
    let aiBaseline: FoodAnalysisResult?
    /// Cover first. Photos rejected for showing people are never here. Set through `updatePhotos`.
    var photos: [CapturedPhoto]
    /// "We left out 1 photo that showed people." Dismissible.
    var removedPhotosNotice: String?
    /// Remote Config turned AI drafting off, so this manual draft says why.
    var showsAIDisabledNote = false

    /// Settings > Display > Show calorie estimates (`@AppStorage` in the views).
    static let showCaloriesKey = "display.showCalories"

    let author: PostAuthor
    private let posts: any PostService
    private let location: any LocationProviding
    private let cooldown: PostCooldown
    let encoder = PostImageEncoder()
    /// Created once so retries write the same document and photo slots.
    private let postId: String
    /// Encoded for upload, by photo ID; nil = couldn't be encoded.
    @ObservationIgnored var encodedPhotos: [UUID: Data?] = [:]
    /// The draft as first shown, to tell whether the user changed anything.
    @ObservationIgnored var initialDraft = PostDraft()
    /// Remote Config word lists, as they were when Review opened. Nil skips the check (previews).
    private let contentFilter: ContentFilter?

    init(photos: [CapturedPhoto], analysis: FoodAnalysisResult?, author: PostAuthor,
         posts: any PostService, location: any LocationProviding, cooldown: PostCooldown = PostCooldown(),
         contentFilter: ContentFilter? = nil) {
        self.photos = photos
        self.contentFilter = contentFilter
        self.aiBaseline = analysis
        self.removedPhotosNotice = analysis.flatMap(Self.removedNotice)
        self.author = author
        self.posts = posts
        self.location = location
        self.cooldown = cooldown
        self.postId = posts.makePostId()
        var draft = analysis.map(PostDraft.init(analysis:)) ?? PostDraft()
        if draft.items.isEmpty { draft.items = [PostDraft.Item()] }
        // GPS only picks the default; it is never stored. Off campus, the user picks.
        if location.isOnCampus, let coordinate = location.lastCoordinate, let nearest = CampusBuilding.nearest(to: coordinate) {
            draft.location = .building(nearest)
        }
        self.draft = draft
        refreshAutoTitle()
        initialDraft = self.draft
    }

    // MARK: Fields

    /// Typing a title switches off the auto-title.
    var title: String {
        get { draft.title }
        set {
            draft.titleIsCustom = true
            draft.title = PostText.limited(newValue, to: AppConfig.postTitleMaxLength)
        }
    }

    var description: String {
        get { draft.description }
        set { draft.description = PostText.limited(newValue, to: AppConfig.postDescriptionMaxLength) }
    }

    var locationDetail: String {
        get { draft.locationDetail }
        set { draft.locationDetail = PostText.limited(newValue, to: AppConfig.postLocationDetailMaxLength) }
    }

    func useSuggestedTitle() {
        draft.titleIsCustom = false
    }

    func addItem() {
        guard draft.items.count < AppConfig.postMaxItems else { return }
        draft.items.append(PostDraft.Item())
    }

    func removeItem(_ id: UUID) {
        draft.items.removeAll { $0.id == id }
    }

    func setItemName(_ name: String, for id: UUID) {
        guard let index = draft.items.firstIndex(where: { $0.id == id }) else { return }
        draft.items[index].name = PostText.limited(name, to: AppConfig.postItemNameMaxLength)
    }

    func toggleAllergen(_ allergen: Allergen) {
        if draft.allergens.contains(allergen) {
            draft.allergens.remove(allergen)
        } else {
            draft.allergens.insert(allergen)
        }
    }

    func addCaution() {
        guard draft.cautions.count < AppConfig.postMaxCautions else { return }
        draft.cautions.append(PostDraft.Caution())
    }

    func removeCaution(_ id: UUID) {
        draft.cautions.removeAll { $0.id == id }
    }

    func setCautionText(_ text: String, for id: UUID) {
        guard let index = draft.cautions.firstIndex(where: { $0.id == id }) else { return }
        draft.cautions[index].text = PostText.limited(text, to: AppConfig.postCautionMaxLength)
    }

    // MARK: Derived state

    /// Only for sorting the building list. Never stored.
    var userCoordinate: Coordinate? {
        location.lastCoordinate
    }

    var issues: [PostDraftValidator.Issue] {
        PostDraftValidator.issues(for: draft, filter: contentFilter)
    }

    /// Shown under a field: soft tips, and content-filter issues (blocking, but the poster must see which field).
    /// Other blocking issues are listed above Publish instead, so an untouched form isn't covered in red.
    func warning(for field: PostDraftValidator.Field) -> PostDraftValidator.Issue? {
        issues.first { $0.field == field && $0.showsInline } ?? issues.first { $0.field == field && !$0.isBlocking }
    }

    var blockingIssues: [PostDraftValidator.Issue] {
        issues.filter(\.isBlocking)
    }

    /// Where "N things left" scrolls to.
    var firstBlockingField: PostDraftValidator.Field? {
        blockingIssues.first?.field
    }

    var canPublish: Bool {
        !issues.contains(where: \.isBlocking) && publishState != .publishing
    }

    func availableUntil(now: Date = .now) -> Date {
        now.addingTimeInterval(Double(draft.durationMinutes) * 60)
    }

    var suggestedTitle: String {
        PostTitleFormatter.title(food: foodForTitle, location: draft.location,
                                 detail: draft.locationDetail, until: availableUntil())
    }

    /// True while the field still holds the AI's value; the AI badge shows only then.
    func isAIValue(_ field: PostDraftValidator.Field) -> Bool {
        guard let ai = aiBaseline else { return false }
        switch field {
        case .title: return !draft.titleIsCustom && itemsMatchAI
        case .description: return PostText.clean(draft.description) == ai.description
        case .items: return itemsMatchAI
        case .cautions: return draft.filledCautions == ai.cautions
        case .servings: return draft.estimatedServings == ai.estimatedServings
        case .location, .locationDetail, .duration, .attestation: return false
        }
    }

    var allergensMatchAI: Bool {
        aiBaseline.map { draft.orderedAllergens == $0.allergens } ?? false
    }

    /// Set when any AI-filled field differs from the AI result.
    var editedAfterAI: Bool {
        guard aiBaseline != nil else { return false }
        return draft.titleIsCustom || !itemsMatchAI || !allergensMatchAI
            || !isAIValue(.description) || !isAIValue(.cautions) || !isAIValue(.servings)
    }

    private var itemsMatchAI: Bool {
        guard let ai = aiBaseline else { return false }
        return draft.filledItems.map { [$0.name, $0.dietary.rawValue] } == ai.items.map { [$0.name, $0.dietary.rawValue] }
    }

    /// The AI's food words until the user changes the items, then the item names.
    private var foodForTitle: String {
        PostTitleFormatter.food(aiTitle: itemsMatchAI ? aiBaseline?.title : nil, items: draft.filledItems)
    }

    private func refreshAutoTitle() {
        guard !draft.titleIsCustom else { return }
        let suggested = suggestedTitle
        if draft.title != suggested { draft.title = suggested }
    }

    // MARK: Publish

    func publish() async -> PublishResult? {
        guard publishState != .publishing else { return nil }
        let remaining = cooldown.secondsRemaining()
        guard remaining == 0 else {
            publishState = .cooldown(remaining)
            return nil
        }
        // The "until" time in the auto-title is taken at publish time.
        refreshAutoTitle()
        guard let submission = PostDraftValidator.submission(from: draft, postId: postId, author: author,
                                                             aiGenerated: aiBaseline != nil,
                                                             editedAfterAI: editedAfterAI,
                                                             filter: contentFilter) else { return nil }
        publishState = .publishing
        do {
            let result = try await posts.publish(submission, photos: await encodedPhotoData())
            cooldown.recordPublish()
            publishState = .idle
            return result
        } catch {
            let appError = error as? AppError ?? .unknown
            publishState = .failed(Self.message(for: appError))
            return nil
        }
    }

    func dismissPublishMessage() {
        if publishState != .publishing { publishState = .idle }
    }

    private static func message(for error: AppError) -> String {
        switch error {
        case .network: "Couldn't publish. Check your connection and try again; your post is still here."
        case .permissionDenied, .unauthorized: "You can't post right now. Try signing out and back in."
        default: error.userMessage
        }
    }
}
