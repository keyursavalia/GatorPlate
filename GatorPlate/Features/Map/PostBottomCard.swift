import SwiftUI

/// Map sheet for a selected pin. Open in Apple Maps is the main action; the ⋯ menu holds Report for everyone
/// but the poster, who gets Mark as gone at the bottom instead.
struct PostBottomCard: View {
    let post: FoodPost
    let viewModel: MapViewModel

    @AppStorage(ReviewViewModel.showCaloriesKey) private var showCalories = true
    @State private var isReporting = false

    var body: some View {
        PostDetailContent(post: post, photoSources: PostPhotoSource.sources(for: post), images: viewModel.images,
                          distanceMeters: viewModel.location.distance(to: post.coordinate),
                          showCalories: showCalories, onOpenInMaps: { viewModel.openInAppleMaps(post) },
                          filterNote: viewModel.isHiddenByFilters(post) ? "Hidden by your filters" : nil) {
            menu
        } actions: {
            PostActionsSection(post: post, viewModel: viewModel)
        }
        .sheet(isPresented: $isReporting) {
            ReportReasonSheet(post: post, viewModel: viewModel)
        }
    }

    @ViewBuilder
    private var menu: some View {
        if !viewModel.isOwnPost(post), !viewModel.reportedPostIds.contains(post.id) {
            Menu {
                Button("Report", systemImage: "flag") { isReporting = true }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.body.weight(.semibold))
                    .frame(minWidth: Theme.Size.minTapTarget, minHeight: Theme.Size.minTapTarget)
                    .contentShape(.rect)
            }
            .accessibilityLabel("More actions")
            .accessibilityHint("Report this post")
        }
    }
}

#Preview {
    Color.clear.sheet(isPresented: .constant(true)) {
        PostBottomCard(post: .sample, viewModel: .preview)
            .presentationDetents([.fraction(0.62), .large])
    }
}

#Preview("AX5") {
    PostBottomCard(post: .sample, viewModel: .preview)
        .dynamicTypeSize(.accessibility5)
}
