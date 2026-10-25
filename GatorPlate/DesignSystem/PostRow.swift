import SwiftUI

/// Feed row, two columns like a profile list: a square photo on the left; title, poster and place, then time
/// left, distance and diet on the right. Stacks at accessibility text sizes. One VoiceOver element, like a pin.
struct PostRow: View {
    let post: FoodPost
    let distanceText: String?
    let images: PostImageCache?
    /// Shows this photo instead of loading it (the success screen's live preview).
    var coverSource: PostPhotoSource?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .headline) private var thumbnailSize: CGFloat = 88

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    thumbnail.frame(maxWidth: .infinity).aspectRatio(4 / 3, contentMode: .fit)
                    details
                }
            } else {
                HStack(alignment: .top, spacing: Theme.Spacing.md) {
                    thumbnail.frame(width: thumbnailSize, height: thumbnailSize)
                    details
                }
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
        .contentShape(.rect)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(PostRow.accessibilityLabel(for: post, distanceText: distanceText))
    }

    private var thumbnail: some View {
        PostPhotoView(source: coverSource ?? post.coverSlot.map { .stored(postId: post.id, slot: $0) },
                      images: images, cornerRadius: Theme.Radius.field)
            .overlay(alignment: .bottomTrailing) {
                if post.photoSlots.count > 1 {
                    Label("\(post.photoSlots.count)", systemImage: "square.stack")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        // Solid: pills over photos never use glass.
                        .background(.black.opacity(0.65), in: .capsule)
                        .padding(Theme.Spacing.xs)
                }
            }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(post.title)
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                .multilineTextAlignment(.leading)
            Text(placeLine)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
            HStack(spacing: Theme.Spacing.sm) {
                TimeRemainingPill(expiresAt: post.expiresAt, isInline: true)
                Label(post.overallDietary.label, systemImage: post.overallDietary.icon)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .labelStyle(TintedIconLabelStyle(tint: post.overallDietary.tint))
            }
            .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// "Org · SSB · 350 ft".
    private var placeLine: String {
        let place = CampusBuilding.byId(post.buildingId)?.shortName ?? post.locationName
        return [post.orgName ?? post.authorName, place, distanceText].compactMap { $0 }.joined(separator: " · ")
    }

    /// "Free food: <title>, <minutes> minutes left, <distance>", as the design system asks for pins.
    static func accessibilityLabel(for post: FoodPost, distanceText: String?, now: Date = .now) -> String {
        let minutes = TimeRemainingPill.minutesLeft(until: post.expiresAt, now: now)
        let place = [post.orgName ?? post.authorName, post.locationName].joined(separator: ", ")
        let photos = post.photoSlots.count > 1 ? " \(post.photoSlots.count) photos." : ""
        return "Free food: \(post.title), \(minutes) minutes left, \(distanceText ?? "distance unknown"). \(place). \(post.overallDietary.label).\(photos)"
    }
}

/// Tinted icon, secondary text.
struct TintedIconLabelStyle: LabelStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: Theme.Spacing.xs) {
            configuration.icon.foregroundStyle(tint)
            configuration.title
        }
    }
}
