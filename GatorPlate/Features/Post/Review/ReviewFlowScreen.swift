import SwiftUI

/// Hosts the review view model and swaps to the success screen once the post is published.
struct ReviewFlowScreen: View {
    let onRetake: () -> Void
    let onViewMap: () -> Void
    let onClose: () -> Void

    @State private var viewModel: ReviewViewModel

    init(
        profile: UserProfile,
        analysis: FoodAnalysisResult?,
        photo: CapturedPhoto?,
        environment: AppEnvironment,
        onRetake: @escaping () -> Void,
        onViewMap: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self.onRetake = onRetake
        self.onViewMap = onViewMap
        self.onClose = onClose
        _viewModel = State(initialValue: ReviewViewModel(
            profile: profile, analysis: analysis, photo: photo, posts: environment.posts,
            location: environment.location, cooldown: environment.cooldown
        ))
    }

    var body: some View {
        if case .published(let post) = viewModel.phase {
            PublishedScreen(post: post, photoDropped: viewModel.photoDropped, onViewMap: onViewMap, onClose: onClose)
        } else {
            ReviewView(viewModel: viewModel, onRetake: onRetake, onClose: onClose)
        }
    }
}
