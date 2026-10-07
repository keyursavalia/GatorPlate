import Foundation
import Observation

/// Post flow steps. Sprint 03: camera -> preview -> placeholder "Next" (AI analysis arrives in Sprint 04).
@MainActor
@Observable
final class PostFlowModel {
    enum Step: Equatable {
        case camera
        case preview(CapturedPhoto)
        case next(CapturedPhoto)
    }

    private(set) var step: Step = .camera
    /// Kept across retakes so the camera keeps its flash setting and configured session.
    let camera: CameraViewModel

    init(camera: any CameraCapturing) {
        self.camera = CameraViewModel(camera: camera)
    }

    func didTake(_ photo: CapturedPhoto) {
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
