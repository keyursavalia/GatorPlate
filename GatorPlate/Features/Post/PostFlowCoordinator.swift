import Observation

/// Steps of the Post flow so far: camera, then preview, then a temporary placeholder (the AI draft lands in Sprint 4).
@Observable
final class PostFlowCoordinator {
    enum Step: Equatable {
        case camera
        case preview(CapturedPhoto)
        case next(CapturedPhoto)
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
        step = .next(photo)
    }
}
