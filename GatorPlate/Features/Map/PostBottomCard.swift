import SwiftUI

/// Map sheet for a selected pin (design system screen 3, Sprint 08 layout). The ⋯ menu holds Report and
/// Open in Apple Maps; the poster sees Mark as gone instead of Report.
struct PostBottomCard: View {
    let post: FoodPost
    let viewModel: MapViewModel
    let isExpanded: Bool

    @AppStorage(ReviewViewModel.showCaloriesKey) private var showCalories = true
    @State private var isReporting = false

    var body: some View {
        PostDetailContent(post: post, photoSources: PostPhotoSource.sources(for: post), images: viewModel.images,
                          distanceMeters: viewModel.location.distance(to: post.coordinate),
                          isExpanded: isExpanded, showCalories: showCalories) {
            menu
        } route: {
            PostRouteSection(post: post, viewModel: viewModel)
        } actions: {
            PostActionsSection(post: post, viewModel: viewModel)
        }
        .sheet(isPresented: $isReporting) {
            ReportReasonSheet(post: post, viewModel: viewModel)
        }
    }

    private var menu: some View {
        Menu {
            Button("Open in Apple Maps", systemImage: "map") { viewModel.openInAppleMaps(post) }
            if !viewModel.isOwnPost(post), !viewModel.reportedPostIds.contains(post.id) {
                Button("Report", systemImage: "flag") { isReporting = true }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.title2)
                .frame(minWidth: Theme.Size.minTapTarget, minHeight: Theme.Size.minTapTarget)
        }
        .accessibilityLabel("More actions")
        .accessibilityHint("Report or open in Apple Maps")
    }
}

#Preview("Medium") {
    PostBottomCard(post: .sample, viewModel: .preview, isExpanded: true)
}

#Preview("Small, AX5") {
    PostBottomCard(post: .sample, viewModel: .preview, isExpanded: false)
        .dynamicTypeSize(.accessibility5)
}
