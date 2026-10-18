import SwiftUI

/// Active posts, newest first, as compact rows (photo left, details right). Realtime, so no pull-to-refresh.
/// Tapping a post opens it on the map.
struct FeedScreen: View {
    let viewModel: FeedViewModel
    let onPostFood: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Free food")
                .overlay(alignment: .bottomTrailing) {
                    PostFAB(action: onPostFood)
                        .padding(Theme.Spacing.lg)
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.content {
        case .loading:
            ProgressView("Loading free food...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed:
            EmptyState(icon: "wifi.exclamationmark", title: "Couldn't load posts",
                       message: "We'll keep trying. Check your connection.")
        case .empty:
            EmptyState(icon: "fork.knife", title: "Nothing posted",
                       message: "No free food right now. Check back soon.")
        case .posts:
            list
        }
    }

    private var list: some View {
        List {
            if viewModel.showsRetryBanner {
                Section {
                    Label("Couldn't refresh posts. Retrying...", systemImage: "wifi.exclamationmark")
                        .font(.subheadline)
                        .foregroundStyle(Theme.Palette.danger)
                }
            }
            Section {
                ForEach(viewModel.posts) { post in
                    Button {
                        viewModel.open(post)
                    } label: {
                        PostRow(post: post, distanceText: viewModel.distanceText(to: post), images: viewModel.images)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens on the map with details and directions")
                }
            } footer: {
                // Room so the last row can scroll clear of the Post food button.
                Color.clear.frame(height: Theme.Spacing.xxl * 2)
            }
        }
        .animation(reduceMotion ? .easeOut(duration: 0.2) : .snappy, value: viewModel.posts.map(\.id))
    }
}

#Preview {
    let session = MainSession.preview
    FeedScreen(viewModel: session.feed, onPostFood: {})
}
