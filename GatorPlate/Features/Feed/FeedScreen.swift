import SwiftUI

/// Active posts as cards (photo on top, details below), filtered like the map and sorted as chosen. Realtime, so no
/// pull-to-refresh. Tapping a post opens it on the map. Every state scrolls under the large title, with the live
/// count and the active filters as removable chips at the top of the content, so the title never disappears.
/// iPhone: one column up to 600 pt. iPad (regular width, standard text sizes): a grid of 2-3 columns across the
/// screen, lined up with the large title.
struct FeedScreen: View {
    let viewModel: FeedViewModel
    let onPostFood: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var showsGrid: Bool {
        horizontalSizeClass == .regular && !dynamicTypeSize.isAccessibilitySize
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    header
                    content
                }
                .padding(.horizontal, showsGrid ? 0 : Theme.Spacing.lg)
                // iPad: the system's margins, so the cards line up with the large title.
                .scenePadding(showsGrid ? .horizontal : [])
                .padding(.top, Theme.Spacing.xs)
                // Room so the last card can scroll clear of the Post food button.
                .padding(.bottom, Theme.Spacing.xxl * 3)
                .frame(maxWidth: showsGrid ? .infinity : 600)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
            // Centered in the visible area (like Blocked people), not in the scrolling content.
            .overlay { emptyState }
            .animation(reduceMotion ? .easeOut(duration: 0.2) : .snappy, value: viewModel.posts.map(\.id))
            .animation(reduceMotion ? .easeOut(duration: 0.2) : .snappy, value: viewModel.chips)
            .navigationTitle("Free food")
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

    /// Live count (with posts on screen), the retry banner and the filter chips.
    @ViewBuilder
    private var header: some View {
        RuntimeNotices()
        if viewModel.content == .posts {
            LiveCountLabel(count: viewModel.posts.count)
        }
        if viewModel.showsRetryBanner {
            Label("Couldn't refresh posts. Retrying...", systemImage: "wifi.exclamationmark")
                .font(.subheadline)
                .foregroundStyle(Theme.Palette.danger)
        }
        if !viewModel.chips.isEmpty {
            FilterChips(chips: viewModel.chips, onRemove: viewModel.remove)
                .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.content == .posts { cards }
    }

    /// Loading and the empty states, over the scroll view so they sit in the middle of the screen while the title
    /// and the filter chips stay in place.
    @ViewBuilder
    private var emptyState: some View {
        switch viewModel.content {
        case .loading:
            ProgressView("Loading free food...")
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
            EmptyView()
        }
    }

    @ViewBuilder
    private var cards: some View {
        if showsGrid {
            VStack(spacing: Theme.Spacing.lg) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: Theme.Spacing.lg, alignment: .top)],
                          spacing: Theme.Spacing.lg) {
                    cardButtons
                }
                hiddenFooter
            }
        } else {
            LazyVStack(spacing: Theme.Spacing.lg) {
                cardButtons
                hiddenFooter
            }
        }
    }

    private var cardButtons: some View {
        ForEach(viewModel.posts) { post in
            Button {
                viewModel.open(post)
            } label: {
                // In the grid every title keeps two lines, so the cards in a row are the same height.
                PostFeedCard(post: post, distanceText: viewModel.distanceText(to: post), images: viewModel.images,
                             reservesTitleLines: showsGrid)
            }
            .buttonStyle(FeedCardButtonStyle())
            .accessibilityHint("Opens on the map with details and directions")
            .transition(.opacity.combined(with: .scale(scale: 0.97)))
        }
    }

    @ViewBuilder
    private var hiddenFooter: some View {
        if let hidden = viewModel.hiddenFooter {
            Text(hidden)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.top, Theme.Spacing.sm)
        }
    }
}

/// "3 posts live" with a softly pulsing green dot (still under Reduce Motion).
private struct LiveCountLabel: View {
    let count: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "circle.fill")
                .font(.system(size: 8))
                .foregroundStyle(Theme.Palette.success)
                .symbolEffect(.pulse, options: .repeat(.continuous), isActive: !reduceMotion)
                .accessibilityHidden(true)
            Text(count == 1 ? "1 post live" : "\(count) posts live")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())
        }
    }
}

/// Cards dim and shrink slightly while pressed.
private struct FeedCardButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
