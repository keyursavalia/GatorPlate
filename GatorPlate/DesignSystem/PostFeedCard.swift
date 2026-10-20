import SwiftUI

/// Feed card, one per post, in the post sheet's style: a whole-photo hero with time left and the photo count on
/// solid pills, then the title, poster and place, and walking distance with the diet mark. Same facts as `PostRow`
/// (which the success screen keeps using) and the same single VoiceOver label.
struct PostFeedCard: View {
    let post: FoodPost
    let distanceText: String?
    let images: PostImageCache?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            hero
            details
                .padding(Theme.Spacing.lg)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: .rect(cornerRadius: Theme.Radius.card))
        .clipShape(.rect(cornerRadius: Theme.Radius.card))
        .contentShape(.rect(cornerRadius: Theme.Radius.card))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(PostRow.accessibilityLabel(for: post, distanceText: distanceText))
    }

    private var hero: some View {
        PostPhotoView(source: post.coverSlot.map { .stored(postId: post.id, slot: $0) }, images: images,
                      cornerRadius: 0, contentMode: .fit, showsBackdrop: true)
            .aspectRatio(16 / 10, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .overlay(alignment: .topLeading) {
                TimeRemainingPill(expiresAt: post.expiresAt, isSolid: true)
                    .padding(Theme.Spacing.md)
            }
            .overlay(alignment: .bottomTrailing) {
                if post.photoSlots.count > 1 {
                    Label("\(post.photoSlots.count)", systemImage: "square.stack")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, Theme.Spacing.sm)
                        .padding(.vertical, Theme.Spacing.xs)
                        // Solid: pills over photos never use glass.
                        .background(.black.opacity(0.65), in: .capsule)
                        .padding(Theme.Spacing.md)
                }
            }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(post.title)
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                .multilineTextAlignment(.leading)
            Text(placeLine)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
            metaRow
        }
    }

    /// Diet mark and walking distance as quiet capsules.
    private var metaRow: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Theme.Spacing.sm))
            : AnyLayout(HStackLayout(spacing: Theme.Spacing.sm))
        return layout {
            metaCapsule(post.overallDietary.label, systemImage: post.overallDietary.icon,
                        tint: post.overallDietary.tint)
            if let distanceText {
                metaCapsule(distanceText, systemImage: "figure.walk", tint: .secondary)
            }
        }
        .padding(.top, Theme.Spacing.xs)
    }

    private func metaCapsule(_ text: String, systemImage: String, tint: Color) -> some View {
        Label(text, systemImage: systemImage)
            .font(.footnote.weight(.medium))
            .foregroundStyle(.secondary)
            .labelStyle(TintedIconLabelStyle(tint: tint))
            .lineLimit(1)
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, 6)
            .background(.background.tertiary, in: .capsule)
    }

    /// "Org · Chavez Center".
    private var placeLine: String {
        let place = CampusBuilding.byId(post.buildingId)?.shortName ?? post.locationName
        return [post.orgName ?? post.authorName, place].joined(separator: " · ")
    }
}

#Preview {
    ScrollView {
        VStack(spacing: Theme.Spacing.md) {
            PostFeedCard(post: .sample, distanceText: "0.6 mi away", images: nil)
            PostFeedCard(post: .sample, distanceText: nil, images: nil)
        }
        .padding()
    }
}

#Preview("AX3") {
    ScrollView {
        PostFeedCard(post: .sample, distanceText: "350 ft", images: nil).padding()
    }
    .dynamicTypeSize(.accessibility3)
}
