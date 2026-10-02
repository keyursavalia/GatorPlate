import SwiftUI

/// Hosts the analysis view model and shows the screen for its current state.
struct AnalysisFlowScreen: View {
    let photo: CapturedPhoto
    let onRetake: () -> Void
    let onManual: () -> Void
    let onClose: () -> Void

    @State private var viewModel: AnalysisViewModel

    init(
        photo: CapturedPhoto,
        analyzer: any FoodAnalyzing,
        onRetake: @escaping () -> Void,
        onManual: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self.photo = photo
        self.onRetake = onRetake
        self.onManual = onManual
        self.onClose = onClose
        _viewModel = State(initialValue: AnalysisViewModel(analyzer: analyzer, jpeg: photo.jpegData))
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle, .analyzing:
                AnalyzingScreen(
                    photo: photo,
                    statusMessage: viewModel.statusMessage,
                    isTakingLong: viewModel.isTakingLong,
                    onCancel: { viewModel.cancel(); onRetake() },
                    onManual: { viewModel.cancel(); onManual() }
                )
            case .success(let result):
                AnalysisResultsScreen(photo: photo, result: result, onRetake: onRetake, onDone: onClose)
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
        .onDisappear { viewModel.cancel() }
    }
}

#Preview("Flow: success") {
    AnalysisFlowScreen(
        photo: PreviewSupport.photo(variant: 1), analyzer: MockFoodAnalyzer(delay: .seconds(2)),
        onRetake: {}, onManual: {}, onClose: {}
    )
    .environment(\.appEnvironment, .mock)
}

#Preview("Flow: not food") {
    AnalysisFlowScreen(
        photo: PreviewSupport.photo(variant: 2), analyzer: MockFoodAnalyzer(scenario: .rejected(.notFood)),
        onRetake: {}, onManual: {}, onClose: {}
    )
    .environment(\.appEnvironment, .mock)
}

#Preview("Flow: offline") {
    AnalysisFlowScreen(
        photo: PreviewSupport.photo(variant: 3), analyzer: MockFoodAnalyzer(scenario: .failure(.network)),
        onRetake: {}, onManual: {}, onClose: {}
    )
    .environment(\.appEnvironment, .mock)
}
