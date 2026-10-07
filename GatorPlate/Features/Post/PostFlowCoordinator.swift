import SwiftUI

/// Full-screen post flow launched by `PostFAB`: Camera -> Preview -> Analysis -> Results, or manual entry.
struct PostFlowCoordinator: View {
    @State private var model: PostFlowModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(camera: any CameraCapturing, analyzer: any FoodAnalyzing) {
        _model = State(initialValue: PostFlowModel(camera: camera, analyzer: analyzer))
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
            case .analysis:
                if let analysis = model.analysis {
                    withCloseBar { analysisContent(analysis) }
                        .transition(transition)
                }
            case .manual(let photo):
                withCloseBar { ManualEntryPlaceholderView(photo: photo) }
                    .transition(transition)
            }
        }
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : .snappy, value: model.step)
    }

    @ViewBuilder
    private func analysisContent(_ analysis: AnalysisViewModel) -> some View {
        Group {
            switch analysis.state {
            case .idle, .analyzing:
                AnalyzingScreen(viewModel: analysis, onCancel: model.cancelAnalysis, onFillManually: model.fillManually)
            case .success(let result):
                AnalysisResultsScreen(photo: analysis.photo, result: result, evalLine: analysis.evalLine,
                                      onRetake: model.retake)
            case .rejected(let reason):
                AnalysisRejectedView(reason: reason, evalLine: analysis.evalLine,
                                     onRetake: model.retake, onFillManually: model.fillManually)
            case .failed(let error):
                AnalysisFailedView(error: error, evalLine: analysis.evalLine,
                                   onRetry: analysis.retry, onFillManually: model.fillManually)
            }
        }
        .transition(.opacity)
        .animation(reduceMotion ? nil : .easeInOut, value: analysis.state)
        .sensoryFeedback(trigger: analysis.state) { _, new in
            switch new {
            case .success: .success
            case .rejected, .failed: .warning
            case .idle, .analyzing: nil
            }
        }
    }

    /// Close sits in its own row so it never covers the photo or scrolling content.
    private func withCloseBar(@ViewBuilder _ content: () -> some View) -> some View {
        VStack(spacing: 0) {
            HStack {
                GlassIconButton(systemImage: "xmark", accessibilityLabel: "Close",
                                accessibilityHint: "Cancels the post", action: close)
                Spacer()
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.top, Theme.Spacing.sm)
            content()
        }
        .background(.background)
    }

    private var transition: AnyTransition {
        reduceMotion ? .opacity : .push(from: .trailing)
    }

    private func close() {
        model.close()
        dismiss()
    }
}

#Preview {
    PostFlowCoordinator(camera: MockCameraService(), analyzer: MockFoodAnalyzer())
}
