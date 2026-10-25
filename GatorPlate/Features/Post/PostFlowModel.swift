import Foundation
import OSLog
import Observation

/// Post flow steps: capture (1-4 photos in a tray) -> AI analysis -> review -> success. "Fill it in myself" goes
/// straight to review. One post, one AI call, one set of items. Everything lives in memory while the flow is open.
@MainActor
@Observable
final class PostFlowModel {
    enum Step: Equatable {
        case capture
        /// Analyzing, then rejection or failure; see `analysis.state`. Success moves on to review.
        case analysis
        /// See `review`.
        case review
        /// See `publishResult`.
        case success
    }

    /// Edit photos from Review changed the photos of an edited AI draft: re-draft or keep the edits?
    enum RedraftChoice: Equatable {
        case none, asking
    }

    private(set) var step: Step = .capture
    /// Kept across the flow so the camera keeps its flash setting and configured session.
    let camera: CameraViewModel
    let tray = PhotoTrayModel()
    private(set) var analysis: AnalysisViewModel?
    private(set) var review: ReviewViewModel?
    private(set) var publishResult: PublishResult?
    /// Capture was opened from Review ("Edit photos"); Next returns to Review.
    private(set) var isEditingPhotos = false
    var redraftChoice = RedraftChoice.none

    private let analyzer: any FoodAnalyzing
    private let runtime: any RuntimeConfigProviding
    private let posts: any PostService
    private let location: any LocationProviding
    private let author: PostAuthor
    @ObservationIgnored private var photosAtEditStart: [UUID] = []

    init(camera: any CameraCapturing, analyzer: any FoodAnalyzing, runtime: any RuntimeConfigProviding,
         posts: any PostService, location: any LocationProviding, author: PostAuthor) {
        self.camera = CameraViewModel(camera: camera)
        self.analyzer = analyzer
        self.runtime = runtime
        self.posts = posts
        self.location = location
        self.author = author
    }

    /// When the flow opens: the analyzer readies its credentials while the user frames the photo.
    func prepareAnalysis() {
        analyzer.prepare()
    }

    // MARK: Capture

    /// "Next" on the capture screen.
    func next() {
        guard !tray.isEmpty else { return }
        guard isEditingPhotos, let review else {
            startAnalysis()
            return
        }
        guard tray.ids != photosAtEditStart else {
            finishEditingPhotos()
            return
        }
        if review.aiBaseline == nil {
            // Manual post: just use the new photos.
            review.updatePhotos(tray.photos)
            finishEditingPhotos()
        } else if review.hasUserEdits {
            redraftChoice = .asking
        } else {
            startAnalysis()
        }
    }

    /// "Re-draft with AI (replaces your edits)".
    func redraftWithAI() {
        redraftChoice = .none
        startAnalysis()
    }

    /// "Keep my edits": the new photos join the existing draft without AI.
    func keepEdits() {
        redraftChoice = .none
        review?.updatePhotos(tray.photos)
        finishEditingPhotos()
    }

    /// "Edit photos" on Review: back to capture with the tray as it was.
    func editPhotos() {
        photosAtEditStart = tray.ids
        isEditingPhotos = true
        step = .capture
    }

    // MARK: Analysis

    private func startAnalysis() {
        // Remote Config `ai_enabled` off: straight to Review, read fresh so turning it back on needs no relaunch.
        guard runtime.current.aiEnabled else {
            skipAnalysis()
            return
        }
        let analysis = AnalysisViewModel(photos: tray.photos, analyzer: analyzer)
        self.analysis = analysis
        step = .analysis
        analysis.start()
    }

    /// AI drafting is switched off: the photos go to Review as a manual draft (edits kept when editing photos).
    private func skipAnalysis() {
        Logger.services.info("AI analysis: ai_disabled")
        endAnalysis()
        if let review, isEditingPhotos {
            review.updatePhotos(tray.photos)
            finishEditingPhotos()
            return
        }
        let newReview = makeReview(analysis: nil)
        newReview.showsAIDisabledNote = true
        review = newReview
        isEditingPhotos = false
        step = .review
    }

    /// Cancel on the Analyzing screen: back to the photos, nothing lost.
    func cancelAnalysis() {
        guard step == .analysis else { return }
        endAnalysis()
        step = isEditingPhotos && review != nil ? .review : .capture
        if step == .review { isEditingPhotos = false }
    }

    /// AI draft ready: photos with people or no food are dropped for good, then Review opens pre-filled.
    /// When re-drafting after Edit photos, the user's place, time and attestation carry over.
    func showReview(with result: FoodAnalysisResult) {
        guard step == .analysis else { return }
        endAnalysis()
        tray.keep(indices: result.keptPhotoIndices)
        let previous = review
        let newReview = makeReview(analysis: result)
        if let previous { newReview.carryOverWhereAndWhen(from: previous) }
        review = newReview
        isEditingPhotos = false
        step = .review
    }

    /// "Retake" after a rejection: photos showing people never stay; the rest go back to the tray.
    func retake() {
        if analysis?.state == .rejected(.containsPeople) { tray.removeAll() }
        endAnalysis()
        step = .capture
    }

    /// Manual entry is always available. Photos rejected for showing people are not carried over.
    func fillManually() {
        if analysis?.state == .rejected(.containsPeople) { tray.removeAll() }
        endAnalysis()
        if let review, isEditingPhotos {
            review.updatePhotos(tray.photos)
            finishEditingPhotos()
            return
        }
        review = makeReview(analysis: nil)
        isEditingPhotos = false
        step = .review
    }

    // MARK: Publish

    func didPublish(_ result: PublishResult) {
        publishResult = result
        review = nil
        step = .success
    }

    /// True when closing would throw away a draft.
    var hasUnsavedDraft: Bool {
        review != nil && step != .success
    }

    func close() {
        endAnalysis()
    }

    private func makeReview(analysis: FoodAnalysisResult?) -> ReviewViewModel {
        ReviewViewModel(photos: tray.photos, analysis: analysis, author: author, posts: posts, location: location,
                        contentFilter: runtime.current.contentFilter)
    }

    private func finishEditingPhotos() {
        isEditingPhotos = false
        step = .review
    }

    private func endAnalysis() {
        analysis?.cancel()
        analysis = nil
    }
}
