import SwiftUI

/// Active posts, newest first. Realtime, so no pull-to-refresh. Tapping a post opens it on the map.
struct FeedScreen: View {
    let viewModel: FeedViewModel
    /// Offers free food alerts once, with the explanation shown before the system prompt.
    let alerts: SettingsViewModel
    let onPostFood: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("feed.hasDismissedAlertsOffer") private var hasDismissedAlertsOffer = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if alerts.shouldOfferAlerts, !hasDismissedAlertsOffer {
                    alertsOffer
                        .padding(.horizontal, Theme.Spacing.lg)
                        .padding(.bottom, Theme.Spacing.sm)
                }
                content
            }
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

    private var alertsOffer: some View {
        Banner(style: .info,
               message: "Get an alert when someone posts free food on campus. Everyone who opts in gets the same alert, and nothing tracks what you pick up.",
               actions: [
                   Banner.Action(title: "Turn on alerts") { Task { await alerts.confirmAlerts() } },
                   Banner.Action(title: "Not now", isPrimary: false) { hasDismissedAlertsOffer = true },
               ])
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: Theme.Spacing.md) {
                if viewModel.showsRetryBanner {
                    Banner(style: .error, message: "Couldn't refresh posts. Retrying...")
                }
                ForEach(viewModel.posts) { post in
                    Button {
                        viewModel.open(post)
                    } label: {
                        PostCard(post: post, distanceText: viewModel.distanceText(to: post), images: viewModel.images)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens on the map with details and directions")
                    .transition(.opacity)
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.top, Theme.Spacing.sm)
            // Room so the last card can scroll clear of the Post food button.
            .padding(.bottom, Theme.Spacing.xxl * 3)
            .animation(reduceMotion ? .easeOut(duration: 0.2) : .snappy, value: viewModel.posts.map(\.id))
        }
    }
}

#Preview {
    let session = MainSession.preview
    FeedScreen(viewModel: session.feed, alerts: session.settings, onPostFood: {})
}
