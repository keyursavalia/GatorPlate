import SwiftUI

/// Post flow step 4: a drawn checkmark, "Your post is live", the post's Feed row, then
/// View on map and Done. Photos that didn't upload show as one warning row.
struct PublishSuccessView: View {
    let result: PublishResult
    /// The flow's photos, by slot, for the live card (no download needed).
    let photos: [CapturedPhoto]
    let onViewMap: () -> Void
    let onDone: () -> Void

    @State private var hasAppeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.xl) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(Theme.Palette.success)
                    .symbolEffect(.drawOn, isActive: !hasAppeared && !reduceMotion)
                    .accessibilityHidden(true)
                VStack(spacing: Theme.Spacing.sm) {
                    Text("Your post is live")
                        .font(.title.bold())
                        .accessibilityAddTraits(.isHeader)
                    Text("Students with alerts on are being notified.")
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)

                PostRow(post: result.post, distanceText: nil, images: nil, coverSource: coverSource)
                    .padding(Theme.Spacing.md)
                    .background(.background.secondary, in: .rect(cornerRadius: Theme.Radius.card))
                    .accessibilityLabel("Your post: " + PostRow.accessibilityLabel(for: result.post, distanceText: nil))

                if result.hasPhotoFailures {
                    Banner(style: .warning, message: photoWarning)
                }

                VStack(spacing: Theme.Spacing.md) {
                    PrimaryButton(title: "View on map", action: onViewMap)
                    SecondaryButton(title: "Done", action: onDone)
                }
            }
            .padding(Theme.Spacing.xl)
            .frame(maxWidth: 500)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(.background)
        .sensoryFeedback(.success, trigger: hasAppeared)
        .task {
            try? await Task.sleep(for: .milliseconds(100))
            hasAppeared = true
        }
    }

    private var coverSource: PostPhotoSource? {
        guard let slot = result.post.coverSlot, photos.indices.contains(slot) else { return nil }
        return .captured(photos[slot])
    }

    private var photoWarning: String {
        result.uploadedPhotos == 0
            ? "Your photos couldn't upload, so the post has no photo."
            : "\(result.uploadedPhotos) of \(result.requestedPhotos) photos uploaded."
    }
}

#Preview {
    PublishSuccessView(result: PublishResult(post: .sample, requestedPhotos: 2), photos: [],
                       onViewMap: {}, onDone: {})
}
