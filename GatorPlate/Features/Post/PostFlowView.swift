import SwiftUI

/// Full-screen cover for the Post flow, launched by `PostFAB`.
struct PostFlowView: View {
    let camera: any CameraProviding

    @State private var coordinator = PostFlowCoordinator()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            switch coordinator.step {
            case .camera:
                CameraScreen(camera: camera, onPhoto: coordinator.captured, onClose: { dismiss() })
                    .transition(.opacity)
            case .preview(let photo):
                PhotoPreviewScreen(photo: photo, onRetake: coordinator.retake, onUse: coordinator.usePhoto)
                    .transition(.opacity)
            case .next(let photo):
                PostNextPlaceholderView(photo: photo, onRetake: coordinator.retake, onClose: { dismiss() })
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: coordinator.step)
    }
}

#Preview("Camera (no hardware)") {
    PostFlowView(camera: MockCameraService())
        .environment(\.appEnvironment, .mock)
}
