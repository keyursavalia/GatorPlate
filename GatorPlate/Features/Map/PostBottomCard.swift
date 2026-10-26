import SwiftUI

/// Map sheet for a selected pin. Open in Apple Maps is the main action; the ⋯ menu holds Report and Block for
/// everyone but the poster, who gets Mark as gone at the bottom instead.
struct PostBottomCard: View {
    let post: FoodPost
    let viewModel: MapViewModel

    @AppStorage(ReviewViewModel.showCaloriesKey) private var showCalories = true
    @State private var isReporting = false
    @State private var isConfirmingGone = false
    @State private var isConfirmingBlock = false

    private var posterName: String { MapViewModel.posterName(post) }

    var body: some View {
        PostDetailContent(post: post, photoSources: PostPhotoSource.sources(for: post), images: viewModel.images,
                          distanceMeters: viewModel.location.distance(to: post.coordinate),
                          showCalories: showCalories, onOpenInMaps: { viewModel.openInAppleMaps(post) },
                          filterNote: viewModel.isHiddenByFilters(post) ? "Hidden by your filters" : nil) {
            menu
        } actions: {
            PostActionsSection(post: post, viewModel: viewModel) { isConfirmingGone = true }
        }
        .sheet(isPresented: $isReporting) {
            ReportReasonSheet(post: post, viewModel: viewModel)
        }
        // A system alert like Sign out, kept off the list rows so it isn't copied onto each one.
        .alert("Mark this food as gone?", isPresented: $isConfirmingGone) {
            Button("Mark as gone", role: .destructive) {
                Task { await viewModel.markGone(post) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("It disappears from the map and feed for everyone.")
        }
        .alert("Block \(posterName)?", isPresented: $isConfirmingBlock) {
            Button("Block", role: .destructive) {
                Task { await viewModel.block(post) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You won't see their posts or get alerts for them. They won't be told. We'll also review their posts.")
        }
    }

    @ViewBuilder
    private var menu: some View {
        if !viewModel.isOwnPost(post) {
            Menu {
                if !viewModel.reportedPosts.contains(post.id) {
                    Button("Report", systemImage: "flag") { isReporting = true }
                }
                Button("Block \(posterName)", systemImage: "hand.raised.fill", role: .destructive) {
                    isConfirmingBlock = true
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.body.weight(.semibold))
                    .frame(minWidth: Theme.Size.minTapTarget, minHeight: Theme.Size.minTapTarget)
                    .contentShape(.rect)
            }
            .accessibilityLabel("More actions")
            .accessibilityHint("Report this post or block the poster")
        }
    }
}
