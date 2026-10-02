import Observation

/// Steps of the Post flow so far: camera, then preview, then AI analysis, with a manual path that Sprint 5 turns into the Review form.
@Observable
final class PostFlowCoordinator {
    enum Step: Equatable {
        case camera
        case preview(CapturedPhoto)
        case analysis(CapturedPhoto)
        case manual(CapturedPhoto)
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

    /// AI never blocks posting: reachable from every analysis screen.
    func fillManually() {
        switch step {
        case .analysis(let photo), .preview(let photo): step = .manual(photo)
        default: break
        }
    }
}
