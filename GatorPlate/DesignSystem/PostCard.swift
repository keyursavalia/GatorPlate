import SwiftUI

/// Feed row: photo, title, org, diet, time remaining and distance. One VoiceOver element, like a map pin.
struct PostCard: View {
    let post: FoodPost
    let distanceText: String?
    let images: PostImageCache?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let photoSize: CGFloat = 76

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    photo.frame(maxWidth: .infinity).frame(height: photoSize * 1.6)
                    details
                }
            } else {
                HStack(alignment: .top, spacing: Theme.Spacing.md) {
                    photo.frame(width: photoSize, height: photoSize)
                    details
                }
            }
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: .rect(cornerRadius: Theme.Radius.card))
        .contentShape(.rect(cornerRadius: Theme.Radius.card))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(PostCard.accessibilityLabel(for: post, distanceText: distanceText))
    }

    private var photo: some View {
        PostPhotoView(postId: post.id, hasPhoto: post.hasPhoto, images: images)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(post.title)
                .font(.headline)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
            Text(post.orgName ?? post.authorName)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Theme.Spacing.sm) { badges }
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) { badges }
            }
            Label(locationLine, systemImage: "mappin.and.ellipse")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var badges: some View {
        TimeRemainingPill(expiresAt: post.expiresAt)
        DietaryBadge(dietary: post.overallDietary)
    }

    private var locationLine: String {
        [post.locationName, distanceText].compactMap { $0 }.joined(separator: " · ")
    }

    /// "Free food: <title>, <minutes> minutes left, <distance>", as the design system asks for pins.
    static func accessibilityLabel(for post: FoodPost, distanceText: String?, now: Date = .now) -> String {
        let minutes = TimeRemainingPill.minutesLeft(until: post.expiresAt, now: now)
        let place = [post.orgName ?? post.authorName, post.locationName].joined(separator: ", ")
        return "Free food: \(post.title), \(minutes) minutes left, \(distanceText ?? "distance unknown"). \(place). \(post.overallDietary.label)."
    }
}

#Preview {
    VStack {
        PostCard(post: .sample, distanceText: "350 ft away", images: nil)
        PostCard(post: .sample, distanceText: nil, images: nil)
            .dynamicTypeSize(.accessibility3)
    }
    .padding()
}
