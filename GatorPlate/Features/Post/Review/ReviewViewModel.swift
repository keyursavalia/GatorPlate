import Foundation
import Observation
import OSLog

/// The Review form (design system screen 4 step 3): AI draft or empty manual draft, edited by the user,
/// validated, then published. State lives in memory only.
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
    /// Form-only preference; calories are still saved on the items.
    var showCalories = true
    /// Nil on the manual path.
    let aiBaseline: FoodAnalysisResult?
    /// Nil when there is no photo, or when it was rejected for showing people.
    let photo: CapturedPhoto?

    private let author: PostAuthor
    private let posts: any PostService
    private let location: any LocationProviding
    private let cooldown: PostCooldown
    private let encoder = PostImageEncoder()
    /// Created once so retries write the same document.
    private let postId: String
    @ObservationIgnored private var encodedPhoto: Data?

    init(photo: CapturedPhoto?, analysis: FoodAnalysisResult?, author: PostAuthor,
         posts: any PostService, location: any LocationProviding, cooldown: PostCooldown = PostCooldown()) {
        self.photo = photo
        self.aiBaseline = analysis
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
        PostDraftValidator.issues(for: draft)
    }

    /// Soft tips shown under a field. Blocking issues are listed above Publish instead, so an untouched
    /// form isn't covered in red.
    func warning(for field: PostDraftValidator.Field) -> PostDraftValidator.Issue? {
        issues.first { $0.field == field && !$0.isBlocking }
    }

    var blockingIssues: [PostDraftValidator.Issue] {
        issues.filter(\.isBlocking)
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

    func publish() async -> FoodPost? {
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
                                                             editedAfterAI: editedAfterAI) else { return nil }
        publishState = .publishing
        do {
            let post = try await posts.publish(submission, imageJPEG: await encodedPhotoData())
            cooldown.recordPublish()
            publishState = .idle
            return post
        } catch {
            let appError = error as? AppError ?? .unknown
            publishState = .failed(Self.message(for: appError))
            return nil
        }
    }

    func dismissPublishMessage() {
        if publishState != .publishing { publishState = .idle }
    }

    private func encodedPhotoData() async -> Data? {
        if let encodedPhoto { return encodedPhoto }
        guard let photo else { return nil }
        let data = await encoder.encode(photo.jpegData)
        encodedPhoto = data
        return data
    }

    private static func message(for error: AppError) -> String {
        switch error {
        case .network: "Couldn't publish. Check your connection and try again; your post is still here."
        case .permissionDenied, .unauthorized: "You can't post right now. Try signing out and back in."
        default: error.userMessage
        }
    }
}
