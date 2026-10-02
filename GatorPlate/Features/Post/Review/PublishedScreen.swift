import SwiftUI

/// Step 4 of the Post flow: confirmation with a success haptic.
struct PublishedScreen: View {
    let post: FoodPost
    let photoDropped: Bool
    let onViewMap: () -> Void
    let onClose: () -> Void

    @State private var appeared = false

    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer()
            VStack(spacing: Theme.Spacing.m) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(Color.success)
                    .accessibilityHidden(true)
                Text("Your post is live")
                    .font(.title.bold())
                Text(post.title)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                Text("Available until \(post.expiresAt.formatted(date: .omitted, time: .shortened)). Stay with the food, and mark it gone when it runs out.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                if photoDropped {
                    Banner(kind: .warning, message: "Your photo couldn't be saved, so the post went out without it.")
                }
            }
            .accessibilityElement(children: .contain)
            Spacer()
            VStack(spacing: Theme.Spacing.s) {
                PrimaryButton(title: "View on map", action: onViewMap)
                Button("Done", action: onClose)
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: Theme.minTapTarget)
            }
        }
        .padding(Theme.Spacing.l)
        .background(Color.surface.ignoresSafeArea())
        .sensoryFeedback(.success, trigger: appeared)
        .onAppear { appeared = true }
    }
}

#Preview("Published") {
    PublishedScreen(post: SampleData.post(), photoDropped: false, onViewMap: {}, onClose: {})
        .environment(\.appEnvironment, .mock)
}

#Preview("Published, photo dropped") {
    PublishedScreen(post: SampleData.post(), photoDropped: true, onViewMap: {}, onClose: {})
        .environment(\.appEnvironment, .mock)
}
