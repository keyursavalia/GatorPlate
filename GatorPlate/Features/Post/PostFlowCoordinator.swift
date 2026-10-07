import SwiftUI

/// Full-screen post flow launched by `PostFAB`: Camera -> Preview -> Next (placeholder).
struct PostFlowCoordinator: View {
    @State private var model: PostFlowModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(camera: any CameraCapturing) {
        _model = State(initialValue: PostFlowModel(camera: camera))
    }

    var body: some View {
        ZStack {
            switch model.step {
            case .camera:
                CameraScreen(viewModel: model.camera, onPhoto: model.didTake, onClose: close)
                    .transition(transition)
            case .preview(let photo):
                PhotoPreviewScreen(photo: photo, onRetake: model.retake, onUse: model.usePhoto, onClose: close)
                    .transition(transition)
            case .next(let photo):
                PostNextPlaceholderView(photo: photo, onClose: close)
                    .transition(transition)
            }
        }
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : .snappy, value: model.step)
    }

    private var transition: AnyTransition {
        reduceMotion ? .opacity : .push(from: .trailing)
    }

    private func close() {
        dismiss()
    }
}

#Preview {
    PostFlowCoordinator(camera: MockCameraService())
}
