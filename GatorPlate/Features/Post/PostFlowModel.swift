import Foundation
import Observation

/// Post flow steps: camera -> preview -> AI analysis -> review -> success. "Fill it in myself" goes straight
/// to an empty review. Everything lives in memory for as long as the flow is open; nothing is written to disk.
@MainActor
@Observable
final class PostFlowModel {
    enum Step: Equatable {
        case camera
        case preview(CapturedPhoto)
        /// Analyzing, then rejection or failure; see `analysis.state`. Success moves on to review.
        case analysis(CapturedPhoto)
        /// See `review`.
        case review
        /// See `publishedPost`.
        case success
    }

    private(set) var step: Step = .camera
    /// Kept across retakes so the camera keeps its flash setting and configured session.
    let camera: CameraViewModel
    private(set) var analysis: AnalysisViewModel?
    private(set) var review: ReviewViewModel?
    private(set) var publishedPost: FoodPost?
    /// A photo was chosen but the published post has none.
    private(set) var photoUploadFailed = false

    private let analyzer: any FoodAnalyzing
    private let posts: any PostService
    private let location: any LocationProviding
    private let author: PostAuthor

    init(camera: any CameraCapturing, analyzer: any FoodAnalyzing, posts: any PostService,
         location: any LocationProviding, author: PostAuthor) {
        self.camera = CameraViewModel(camera: camera)
        self.analyzer = analyzer
        self.posts = posts
        self.location = location
        self.author = author
    }

    func didTake(_ photo: CapturedPhoto) {
        step = .preview(photo)
    }

    /// Drops the photo (and any analysis or draft) and returns to the camera.
    func retake() {
        endAnalysis()
        review = nil
        step = .camera
    }

    /// Switches to the Analyzing screen immediately, then starts the request.
    func usePhoto() {
        guard case .preview(let photo) = step else { return }
        let analysis = AnalysisViewModel(photo: photo, analyzer: analyzer)
        self.analysis = analysis
        step = .analysis(photo)
        analysis.start()
    }

    /// Cancel on the Analyzing screen: back to the photo, nothing lost.
    func cancelAnalysis() {
        guard case .analysis(let photo) = step else { return }
        endAnalysis()
        step = .preview(photo)
    }

    /// AI draft ready: open the Review form pre-filled. AI never publishes on its own.
    func showReview(with result: FoodAnalysisResult) {
        guard case .analysis(let photo) = step else { return }
        endAnalysis()
        review = makeReview(photo: photo, analysis: result)
        step = .review
    }

    /// Manual entry is always available. A photo rejected for showing people is not carried over.
    func fillManually() {
        var photo: CapturedPhoto?
        switch step {
        case .preview(let current), .analysis(let current): photo = current
        case .camera, .review, .success: photo = nil
        }
        if analysis?.state == .rejected(.containsPeople) { photo = nil }
        endAnalysis()
        review = makeReview(photo: photo, analysis: nil)
        step = .review
    }

    func didPublish(_ post: FoodPost) {
        photoUploadFailed = review?.photo != nil && !post.hasPhoto
        publishedPost = post
        review = nil
        step = .success
    }

    /// True when closing would throw away a draft.
    var hasUnsavedDraft: Bool {
        step == .review
    }

    func close() {
        endAnalysis()
    }

    private func makeReview(photo: CapturedPhoto?, analysis: FoodAnalysisResult?) -> ReviewViewModel {
        ReviewViewModel(photo: photo, analysis: analysis, author: author, posts: posts, location: location)
    }

    private func endAnalysis() {
        analysis?.cancel()
        analysis = nil
    }
}
