import SwiftUI

/// Full-screen cover for the Post flow, launched by `PostFAB`.
struct PostFlowView: View {
    let camera: any CameraProviding
    let profile: UserProfile
    let onViewMap: () -> Void

    @State private var coordinator = PostFlowCoordinator()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appEnvironment) private var environment

    var body: some View {
        ZStack {
            switch coordinator.step {
            case .camera:
                CameraScreen(
                    camera: camera, onPhoto: coordinator.captured, onClose: { dismiss() },
                    onManual: coordinator.fillManually
                )
                .transition(.opacity)
            case .preview(let photo):
                PhotoPreviewScreen(photo: photo, onRetake: coordinator.retake, onUse: coordinator.usePhoto)
                    .transition(.opacity)
            case .analysis(let photo):
                AnalysisFlowScreen(
                    photo: photo, analyzer: environment.analyzer,
                    onAccepted: coordinator.analysisAccepted,
                    onRetake: coordinator.retake, onManual: coordinator.fillManually, onClose: { dismiss() }
                )
                .transition(.opacity)
            case .review(let photo, let analysis):
                ReviewFlowScreen(
                    profile: profile, analysis: analysis, photo: photo, environment: environment,
                    onRetake: coordinator.retake,
                    onViewMap: { dismiss(); onViewMap() },
                    onClose: { dismiss() }
                )
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: coordinator.step)
    }
}

#Preview("Camera (no hardware)") {
    PostFlowView(camera: MockCameraService(), profile: SampleData.profile, onViewMap: {})
        .environment(\.appEnvironment, .mock)
}
