import SwiftUI

/// The post detail layout shared by the map sheet and Review's Preview. Small detent: thumbnail, title, time,
/// poster, walk time and directions. Medium and up: hero photos, title with a ⋯ menu, poster and place,
/// stat tiles, directions, description, diet and allergens, poster actions.
struct PostDetailContent<MenuContent: View, Route: View, Actions: View>: View {
    let post: FoodPost
    let photoSources: [PostPhotoSource]
    let images: PostImageCache?
    /// Straight-line meters from the user, when known.
    let distanceMeters: Double?
    let isExpanded: Bool
    let showCalories: Bool
    @ViewBuilder var menu: MenuContent
    @ViewBuilder var route: Route
    @ViewBuilder var actions: Actions

    @ScaledMetric(relativeTo: .headline) private var thumbnailSize: CGFloat = 56

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                if isExpanded {
                    expanded
                } else {
                    compact
                }
            }
            .padding(Theme.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    // MARK: Small detent

    @ViewBuilder
    private var compact: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            if let cover = photoSources.first {
                PostPhotoView(source: cover, images: images, cornerRadius: Theme.Radius.field)
                    .frame(width: thumbnailSize, height: thumbnailSize)
            }
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(post.title)
                    .font(.headline)
                    .lineLimit(2)
                    .accessibilityAddTraits(.isHeader)
                Text(posterAndWalk)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            TimeRemainingPill(expiresAt: post.expiresAt)
        }
        route
    }

    // MARK: Medium and large

    @ViewBuilder
    private var expanded: some View {
        if !photoSources.isEmpty {
            PhotoCarousel(sources: photoSources, images: images)
        }
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            Text(post.title)
                .font(.title3.bold())
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)
            menu
        }
        InfoRow(primary: posterName, secondary: placeLine) {
            MonogramAvatar(name: posterName)
        }
        statTiles
        route
        if !post.description.isEmpty {
            Text(post.description).font(.body)
        }
        PostDietSection(post: post, showCalories: showCalories)
        actions
    }

    private var statTiles: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Theme.Spacing.sm) { tiles }
            VStack(spacing: Theme.Spacing.sm) { tiles }
        }
    }

    @ViewBuilder
    private var tiles: some View {
        TimelineView(CountdownSchedule(expiresAt: post.expiresAt)) { context in
            let minutes = TimeRemainingPill.minutesLeft(until: post.expiresAt, now: context.date)
            StatTile(value: "\(minutes) min", caption: "left", systemImage: "clock",
                     tint: minutes < 10 ? Theme.Palette.warning : .primary)
        }
        if let walk = walkMinutes {
            StatTile(value: "\(walk) min", caption: "walk", systemImage: "figure.walk")
        }
        if let servings = post.estimatedServings {
            StatTile(value: "~\(servings)", caption: "servings", systemImage: "takeoutbag.and.cup.and.straw")
        }
    }

    // MARK: Text

    private var posterName: String {
        post.orgName ?? post.authorName
    }

    private var placeLine: String {
        [post.locationName, post.locationDetail].compactMap { $0 }.joined(separator: ", ")
    }

    private var walkMinutes: Int? {
        distanceMeters.map(DistanceText.walkMinutes(meters:))
    }

    private var posterAndWalk: String {
        [posterName, walkMinutes.map { "\($0) min walk" }].compactMap { $0 }.joined(separator: " · ")
    }
}
