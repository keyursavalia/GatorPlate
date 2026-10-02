import SwiftUI

/// Hosts the analysis view model and shows the screen for its current state.
struct AnalysisFlowScreen: View {
    let photo: CapturedPhoto
    let onAccepted: (FoodAnalysisResult) -> Void
    let onRetake: () -> Void
    let onManual: () -> Void
    let onClose: () -> Void

    @State private var viewModel: AnalysisViewModel

    init(
        photo: CapturedPhoto,
        analyzer: any FoodAnalyzing,
        onAccepted: @escaping (FoodAnalysisResult) -> Void,
        onRetake: @escaping () -> Void,
        onManual: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self.photo = photo
        self.onAccepted = onAccepted
        self.onRetake = onRetake
        self.onManual = onManual
        self.onClose = onClose
        _viewModel = State(initialValue: AnalysisViewModel(analyzer: analyzer, jpeg: photo.jpegData))
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle, .analyzing, .success:
                // `.success` hands straight to the Review form (via `onChange` below), so the poster never
                // sees a read-only copy of the draft.
                AnalyzingScreen(
                    photo: photo,
                    statusMessage: viewModel.statusMessage,
                    isTakingLong: viewModel.isTakingLong,
                    onCancel: { viewModel.cancel(); onRetake() },
                    onManual: { viewModel.cancel(); onManual() }
                )
            case .rejected(let reason):
                AnalysisFailureScreen(
                    title: reason.title, message: reason.detail, onRetake: onRetake, onManual: onManual
                )
            case .failed(let error):
                AnalysisFailureScreen(
                    title: "Couldn't analyze the photo", message: error.analysisMessage,
                    retryTitle: "Try again", onRetry: viewModel.retry, onRetake: onRetake, onManual: onManual
                )
            }
        }
        .task { viewModel.start() }
        .onChange(of: viewModel.state) { _, state in
            if case .success(let result) = state { onAccepted(result) }
        }
        .onDisappear { viewModel.cancel() }
    }
}

#Preview("Flow: success") {
    AnalysisFlowScreen(
        photo: PreviewSupport.photo(variant: 1), analyzer: MockFoodAnalyzer(delay: .seconds(2)),
        onAccepted: { _ in }, onRetake: {}, onManual: {}, onClose: {}
    )
    .environment(\.appEnvironment, .mock)
}

#Preview("Flow: not food") {
    AnalysisFlowScreen(
        photo: PreviewSupport.photo(variant: 2), analyzer: MockFoodAnalyzer(scenario: .rejected(.notFood)),
        onAccepted: { _ in }, onRetake: {}, onManual: {}, onClose: {}
    )
    .environment(\.appEnvironment, .mock)
}

#Preview("Flow: offline") {
    AnalysisFlowScreen(
        photo: PreviewSupport.photo(variant: 3), analyzer: MockFoodAnalyzer(scenario: .failure(.network)),
        onAccepted: { _ in }, onRetake: {}, onManual: {}, onClose: {}
    )
    .environment(\.appEnvironment, .mock)
}
