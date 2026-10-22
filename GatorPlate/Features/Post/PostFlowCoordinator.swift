import SwiftUI

/// Full-screen post flow launched by `PostFAB`: Capture (1-4 photos) -> Analysis -> Review -> Success,
/// or straight to Review via "Fill it in myself".
struct PostFlowCoordinator: View {
    @State private var model: PostFlowModel
    @State private var isConfirmingClose = false
    /// Receives the published post's ID.
    let onViewMap: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(camera: any CameraCapturing, analyzer: any FoodAnalyzing, runtime: any RuntimeConfigProviding,
         posts: any PostService, location: any LocationProviding, author: PostAuthor,
         onViewMap: @escaping (String) -> Void) {
        _model = State(initialValue: PostFlowModel(camera: camera, analyzer: analyzer, runtime: runtime, posts: posts,
                                                   location: location, author: author))
        self.onViewMap = onViewMap
    }

    var body: some View {
        @Bindable var model = model
        ZStack {
            switch model.step {
            case .capture:
                CameraScreen(viewModel: model.camera, tray: model.tray, onNext: model.next, onClose: requestClose,
                             onFillManually: model.fillManually)
                    .transition(transition)
            case .analysis:
                if let analysis = model.analysis {
                    withCloseBar { analysisContent(analysis) }
                        .transition(transition)
                }
            case .review:
                if let review = model.review {
                    ReviewView(viewModel: review, onClose: requestClose, onEditPhotos: model.editPhotos,
                               onPublished: model.didPublish)
                        .transition(transition)
                }
            case .success:
                if let result = model.publishResult {
                    PublishSuccessView(result: result, photos: model.tray.photos, onViewMap: viewMap, onDone: close)
                        .transition(.opacity)
                }
            }
        }
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : .snappy, value: model.step)
        .task { model.prepareAnalysis() }
        .confirmationDialog(closeTitle, isPresented: $isConfirmingClose, titleVisibility: .visible) {
            Button("Discard", role: .destructive, action: close)
            Button("Keep editing", role: .cancel) {}
        } message: {
            Text("Nothing has been published yet.")
        }
        .confirmationDialog("Your photos changed", isPresented: isAskingRedraft, titleVisibility: .visible) {
            Button("Re-draft with AI (replaces your edits)", action: model.redraftWithAI)
            Button("Keep my edits", action: model.keepEdits)
        } message: {
            Text("AI can draft the post again from the new photos.")
        }
    }

    @ViewBuilder
    private func analysisContent(_ analysis: AnalysisViewModel) -> some View {
        Group {
            switch analysis.state {
            case .idle, .analyzing, .success:
                AnalyzingScreen(viewModel: analysis, onCancel: model.cancelAnalysis, onFillManually: model.fillManually)
            case .rejected(let reason):
                AnalysisRejectedView(reason: reason, photos: analysis.photos,
                                     onRetake: model.retake, onFillManually: model.fillManually)
            case .failed(let error):
                AnalysisFailedView(error: error, photos: analysis.photos,
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

    /// Close sits in its own row so it never covers the photos or scrolling content.
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

    private var closeTitle: String {
        if model.hasUnsavedDraft { return "Discard this post?" }
        let count = model.tray.photos.count
        return count == 1 ? "Discard 1 photo?" : "Discard \(count) photos?"
    }

    private var isAskingRedraft: Binding<Bool> {
        Binding(get: { model.redraftChoice == .asking },
                set: { if !$0, model.redraftChoice == .asking { model.keepEdits() } })
    }

    private func requestClose() {
        if model.hasUnsavedDraft || (!model.tray.isEmpty && model.step != .success) {
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
        if let post = model.publishResult?.post { onViewMap(post.id) }
        close()
    }
}

#Preview {
    PostFlowCoordinator(camera: MockCameraService(), analyzer: MockFoodAnalyzer(), runtime: MockRuntimeConfig(),
                        posts: MockPostService(),
                        location: MockLocationProvider(),
                        author: PostAuthor(uid: "mock-uid", displayName: "Mock Student", orgName: nil),
                        onViewMap: { _ in })
}
