import SwiftUI

/// Active posts as compact rows (photo left, details right), filtered like the map and sorted as chosen. Realtime,
/// so no pull-to-refresh. Tapping a post opens it on the map. Active filters show as removable chips under the title.
struct FeedScreen: View {
    let viewModel: FeedViewModel
    let onPostFood: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        @Bindable var viewModel = viewModel
        NavigationStack {
            content
                .navigationTitle("Free food")
                .safeAreaInset(edge: .top, spacing: 0) {
                    if !viewModel.chips.isEmpty {
                        FilterChips(chips: viewModel.chips, onRemove: viewModel.remove)
                            .padding(.horizontal, Theme.Spacing.lg)
                            .padding(.vertical, Theme.Spacing.xs)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.bar)
                    }
                }
                .toolbar {
                    // The same glass circle as the Map's; the toolbar's own capsule is hidden.
                    ToolbarItem(placement: .topBarTrailing) {
                        FilterButton(activeCount: viewModel.filterCount, action: viewModel.openFilters)
                    }
                    .sharedBackgroundVisibility(.hidden)
                }
                .overlay(alignment: .bottomTrailing) {
                    PostFAB(action: onPostFood)
                        .padding(Theme.Spacing.lg)
                }
                .sheet(isPresented: $viewModel.isFilterSheetPresented, onDismiss: viewModel.filterSheetDidDismiss) {
                    PostFilterSheet(store: viewModel.browse.filters, browse: viewModel.browse, showsSort: true,
                                    notificationPicks: viewModel.browse.notificationPicks)
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
        case .allHidden:
            EmptyState(icon: "line.3.horizontal.decrease", title: "Nothing matches your filters",
                       message: viewModel.hiddenFooter ?? "", actionTitle: "Clear filters",
                       action: viewModel.clearFilters)
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
                VStack(spacing: Theme.Spacing.sm) {
                    if let hidden = viewModel.hiddenFooter {
                        Text(hidden)
                            .frame(maxWidth: .infinity)
                    }
                    // Room so the last row can scroll clear of the Post food button.
                    Color.clear.frame(height: Theme.Spacing.xxl * 2)
                }
            }
        }
        .animation(reduceMotion ? .easeOut(duration: 0.2) : .snappy, value: viewModel.posts.map(\.id))
    }
}

#Preview {
    let session = MainSession.preview
    FeedScreen(viewModel: session.feed, onPostFood: {})
}

#Preview("AX5") {
    let session = MainSession.preview
    FeedScreen(viewModel: session.feed, onPostFood: {})
        .dynamicTypeSize(.accessibility5)
}
