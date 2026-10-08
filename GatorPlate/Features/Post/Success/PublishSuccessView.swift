import SwiftUI

/// Post flow step 4: confirmation with a success haptic and "View on map".
struct PublishSuccessView: View {
    let post: FoodPost
    /// True when a photo was chosen but couldn't be uploaded.
    let photoFailed: Bool
    let onViewMap: () -> Void
    let onDone: () -> Void

    @State private var hasAppeared = false

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.xl) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(Theme.Palette.success)
                    .accessibilityHidden(true)
                VStack(spacing: Theme.Spacing.sm) {
                    Text("Your post is live")
                        .font(.title.bold())
                        .accessibilityAddTraits(.isHeader)
                    Text(verbatim: post.title)
                        .font(.headline)
                    Text("Available until \(post.expiresAt.formatted(date: .omitted, time: .shortened)) at \(post.locationName).")
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)

                if photoFailed {
                    Banner(style: .warning, message: "Your photo couldn't upload, so the post has no photo.")
                }

                VStack(spacing: Theme.Spacing.md) {
                    PrimaryButton(title: "View on map", action: onViewMap)
                    Button(action: onDone) {
                        Text("Done")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: Theme.Size.primaryButtonHeight)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .tint(Theme.Palette.brandPurple)
                }
            }
            .padding(Theme.Spacing.xl)
            .frame(maxWidth: 500)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(.background)
        .sensoryFeedback(.success, trigger: hasAppeared)
        .onAppear { hasAppeared = true }
    }
}

#Preview {
    PublishSuccessView(post: .sample, photoFailed: true, onViewMap: {}, onDone: {})
}
