import Observation

/// Steps of the Post flow: camera, preview, AI analysis, then the Review form (with the success screen inside it).
/// The manual path skips the AI (and optionally the photo) and goes straight to an empty Review form.
@Observable
final class PostFlowCoordinator {
    enum Step: Equatable {
        case camera
        case preview(CapturedPhoto)
        case analysis(CapturedPhoto)
        /// `analysis` is nil on the manual path; `photo` is nil when the poster skipped the photo.
        case review(photo: CapturedPhoto?, analysis: FoodAnalysisResult?)
    }

    private(set) var step: Step = .camera

    func captured(_ photo: CapturedPhoto) {
        step = .preview(photo)
    }

    func retake() {
        step = .camera
    }

    func usePhoto() {
        guard case .preview(let photo) = step else { return }
        step = .analysis(photo)
    }

    /// The AI draft was accepted: the poster still reviews and edits everything before publishing.
    func analysisAccepted(_ result: FoodAnalysisResult) {
        guard case .analysis(let photo) = step else { return }
        step = .review(photo: photo, analysis: result)
    }

    /// AI never blocks posting: reachable from the camera and from every analysis screen.
    func fillManually() {
        switch step {
        case .analysis(let photo), .preview(let photo): step = .review(photo: photo, analysis: nil)
        case .camera: step = .review(photo: nil, analysis: nil)
        case .review: break
        }
    }
}
