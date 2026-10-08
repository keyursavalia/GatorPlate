import SwiftUI

/// Full-screen post flow launched by `PostFAB`: Camera -> Preview -> Analysis -> Review -> Success,
/// or straight to an empty Review via "Fill it in myself".
struct PostFlowCoordinator: View {
    @State private var model: PostFlowModel
    @State private var isConfirmingClose = false
    let onViewMap: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(camera: any CameraCapturing, analyzer: any FoodAnalyzing, posts: any PostService,
         location: any LocationProviding, author: PostAuthor, onViewMap: @escaping () -> Void) {
        _model = State(initialValue: PostFlowModel(camera: camera, analyzer: analyzer, posts: posts,
                                                   location: location, author: author))
        self.onViewMap = onViewMap
    }

    var body: some View {
        ZStack {
            switch model.step {
            case .camera:
                CameraScreen(viewModel: model.camera, onPhoto: model.didTake, onClose: close,
                             onFillManually: model.fillManually)
                    .transition(transition)
            case .preview(let photo):
                PhotoPreviewScreen(photo: photo, onRetake: model.retake, onUse: model.usePhoto, onClose: close)
                    .transition(transition)
            case .analysis:
                if let analysis = model.analysis {
                    withCloseBar { analysisContent(analysis) }
                        .transition(transition)
                }
            case .review:
                if let review = model.review {
                    withCloseBar {
                        ReviewView(viewModel: review, onRetake: model.retake, onPublished: model.didPublish)
                    }
                    .transition(transition)
                }
            case .success:
                if let post = model.publishedPost {
                    PublishSuccessView(post: post, photoFailed: model.photoUploadFailed,
                                       onViewMap: viewMap, onDone: close)
                        .transition(.opacity)
                }
            }
        }
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : .snappy, value: model.step)
        .confirmationDialog("Discard this post?", isPresented: $isConfirmingClose, titleVisibility: .visible) {
            Button("Discard", role: .destructive, action: close)
            Button("Keep editing", role: .cancel) {}
        } message: {
            Text("Nothing has been published yet.")
        }
    }

    @ViewBuilder
    private func analysisContent(_ analysis: AnalysisViewModel) -> some View {
        Group {
            switch analysis.state {
            case .idle, .analyzing, .success:
                AnalyzingScreen(viewModel: analysis, onCancel: model.cancelAnalysis, onFillManually: model.fillManually)
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
        .onChange(of: analysis.state) { _, new in
            if case .success(let result) = new { model.showReview(with: result) }
        }
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
                                accessibilityHint: "Cancels the post", action: requestClose)
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

    private func requestClose() {
        if model.hasUnsavedDraft {
            isConfirmingClose = true
        } else {
            close()
        }
    }

    private func close() {
        model.close()
        dismiss()
    }

    private func viewMap() {
        onViewMap()
        close()
    }
}

#Preview {
    PostFlowCoordinator(camera: MockCameraService(), analyzer: MockFoodAnalyzer(), posts: MockPostService(),
                        location: MockLocationProvider(),
                        author: PostAuthor(uid: "mock-uid", displayName: "Mock Student", orgName: nil),
                        onViewMap: {})
}
