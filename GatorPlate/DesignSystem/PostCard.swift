import SwiftUI

/// Feed row: photo, title, org, badges, time remaining, distance. Reads as one accessibility element.
struct PostCard: View {
    let post: FoodPost
    var distanceText: String?

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.m) {
            PostPhotoView(postID: post.id, hasPhoto: post.hasPhoto)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                Text(post.title)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                Text(post.orgName ?? post.authorName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: Theme.Spacing.s) { pills }
                    VStack(alignment: .leading, spacing: Theme.Spacing.s) { pills }
                }
                Label(locationText, systemImage: "mappin.and.ellipse")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Theme.Spacing.m)
        .background(Color.surfaceSecondary.opacity(0.6), in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spokenLabel)
    }

    @ViewBuilder private var pills: some View {
        TimeRemainingPill(expiresAt: post.expiresAt)
        DietaryBadge(dietary: post.overallDietary)
    }

    private var locationText: String {
        var text = post.locationName
        if let distanceText { text += ", \(distanceText) away" }
        return text
    }

    /// The pill is ignored for VoiceOver inside the combined element, so the time is spoken here.
    private var spokenLabel: String {
        let minutes = max(0, Int((post.expiresAt.timeIntervalSinceNow / 60).rounded(.up)))
        var label = "Free food: \(post.title), \(post.orgName ?? post.authorName), \(minutes) minutes left"
        label += ", \(post.overallDietary.label)"
        label += ", at \(post.locationName)"
        if let distanceText { label += ", \(distanceText) away" }
        return label
    }
}

#Preview("Card") {
    PostCard(post: SampleData.mapPosts()[0], distanceText: "120 m")
        .padding()
        .environment(\.appEnvironment, .mock)
}

#Preview("Card, large text") {
    PostCard(post: SampleData.mapPosts()[0], distanceText: "120 m")
        .padding()
        .dynamicTypeSize(.accessibility3)
        .environment(\.appEnvironment, .mock)
}
