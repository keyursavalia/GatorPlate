import SwiftUI

/// Feed card, image-led: the cover photo (16:9) with a solid time pill and a photo-count badge, then the title,
/// a meta line (poster · place · distance), the diet badge and up to two allergen chips. No photo shows a branded
/// band. One VoiceOver element, like a map pin.
struct PostCard: View {
    let post: FoodPost
    let distanceText: String?
    let images: PostImageCache?
    /// Shows this photo as the cover instead of loading it (the success screen's live preview).
    var coverSource: PostPhotoSource?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private static let maxAllergenChips = 2

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            cover
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text(post.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                    .multilineTextAlignment(.leading)
                Text(metaLine)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                FlowLayout {
                    DietaryBadge(dietary: post.overallDietary)
                    ForEach(post.allergenWarnings.prefix(Self.maxAllergenChips), id: \.self) { AllergenChip(allergen: $0) }
                    if post.allergenWarnings.count > Self.maxAllergenChips {
                        Text("+\(post.allergenWarnings.count - Self.maxAllergenChips)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.Palette.warning)
                            .padding(.horizontal, Theme.Spacing.sm)
                            .frame(minHeight: 28)
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.bottom, Theme.Spacing.md)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: .rect(cornerRadius: Theme.Radius.card))
        .contentShape(.rect(cornerRadius: Theme.Radius.card))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(PostCard.accessibilityLabel(for: post, distanceText: distanceText))
    }

    @ViewBuilder
    private var cover: some View {
        Group {
            if let source = coverSource ?? post.coverSlot.map({ PostPhotoSource.stored(postId: post.id, slot: $0) }) {
                PostPhotoView(source: source, images: images,
                              cornerRadius: Theme.Radius.photo)
                    .aspectRatio(16 / 9, contentMode: .fit)
            } else {
                // Branded band instead of an empty photo.
                ZStack {
                    Theme.Palette.brandPurple.opacity(0.12)
                    Image(systemName: "fork.knife")
                        .font(.title)
                        .foregroundStyle(Theme.Palette.brandPurple)
                }
                .frame(height: 72)
                .clipShape(.rect(cornerRadius: Theme.Radius.photo))
            }
        }
        .overlay(alignment: .topLeading) {
            TimeRemainingPill(expiresAt: post.expiresAt, isSolid: true)
                .padding(Theme.Spacing.sm)
        }
        .overlay(alignment: .topTrailing) {
            if post.photoSlots.count > 1 {
                Label("\(post.photoSlots.count)", systemImage: "photo.stack")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, Theme.Spacing.sm)
                    .padding(.vertical, Theme.Spacing.xs)
                    // Solid: pills over photos never use glass.
                    .background(.black.opacity(0.65), in: .capsule)
                    .padding(Theme.Spacing.sm)
            }
        }
        .padding([.horizontal, .top], Theme.Spacing.xs)
    }

    /// "Org · SSB · 350 ft away".
    private var metaLine: String {
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

#Preview {
    ScrollView {
        VStack {
            PostCard(post: .sample, distanceText: "350 ft away", images: nil)
            PostCard(post: .sample, distanceText: nil, images: nil)
                .dynamicTypeSize(.accessibility3)
        }
        .padding()
    }
}
