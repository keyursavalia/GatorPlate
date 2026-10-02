import SwiftUI

/// Every active post as a list: a complete way to find and reach food without touching the map.
struct FeedView: View {
    let viewModel: FeedViewModel

    var body: some View {
        NavigationStack {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.surface)
                .navigationTitle("Free food")
        }
    }

    @ViewBuilder private var content: some View {
        if viewModel.isLoading {
            ProgressView("Looking for free food...")
        } else if viewModel.showsEmptyState {
            EmptyState(
                systemImage: "fork.knife",
                title: "No free food right now",
                message: "Check back soon."
            )
        } else {
            list
        }
    }

    private var list: some View {
        List(viewModel.posts) { post in
            Button { viewModel.open(post) } label: {
                PostCard(post: post, distanceText: viewModel.distanceText(to: post))
            }
            .buttonStyle(.plain)
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .accessibilityHint("Shows this post on the map, with directions")
            .accessibilityAddTraits(.isButton)
        }
        .listStyle(.plain)
        .animation(.default, value: viewModel.posts.map(\.id))
    }
}

#Preview("Feed") {
    let repository = PostsRepository(service: MockPostService())
    repository.apply(snapshot: SampleData.mapPosts())
    let location = UserLocationModel(location: MockLocationProvider())
    return FeedView(
        viewModel: FeedViewModel(repository: repository, location: location, navigation: NavigationModel())
    )
    .environment(\.appEnvironment, .mock)
}

#Preview("Feed, empty") {
    let repository = PostsRepository(service: MockPostService())
    repository.apply(snapshot: [])
    return FeedView(
        viewModel: FeedViewModel(
            repository: repository,
            location: UserLocationModel(location: MockLocationProvider()),
            navigation: NavigationModel()
        )
    )
    .environment(\.appEnvironment, .mock)
}
