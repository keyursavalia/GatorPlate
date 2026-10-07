import SwiftUI

/// The photo can't become a post (not food, people, unclear). Offers a retake or the manual path.
struct AnalysisRejectedView: View {
    let reason: FoodAnalysisRejection
    var evalLine: String?
    let onRetake: () -> Void
    let onFillManually: () -> Void

    var body: some View {
        AnalysisMessageLayout(icon: content.icon, title: content.title, message: content.message, evalLine: evalLine) {
            PrimaryButton(title: "Retake photo", action: onRetake)
            Button(action: onFillManually) {
                Text("Fill it in myself")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: Theme.Size.primaryButtonHeight)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .tint(Theme.Palette.brandPurple)
        }
    }

    private var content: (icon: String, title: String, message: String) {
        switch reason {
        case .notFood:
            ("questionmark.square.dashed", "That doesn't look like food",
             "Try another photo of the food, or fill in the post yourself.")
        case .containsPeople:
            ("person.crop.square.badge.camera", "Please avoid photographing people",
             "Retake the photo with only the food in frame. This photo won't be used.")
        case .lowConfidence:
            ("eye.trianglebadge.exclamationmark", "We couldn't tell what this is",
             "Try a closer, brighter photo of the food, or fill in the post yourself.")
        }
    }
}

/// Shared layout for full-screen analysis messages: icon, title, message and actions.
struct AnalysisMessageLayout<Actions: View>: View {
    let icon: String
    let title: String
    let message: String
    var evalLine: String?
    @ViewBuilder let actions: Actions

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.xl) {
                Image(systemName: icon)
                    .font(.system(size: 56))
                    .foregroundStyle(Theme.Palette.brandPurple)
                    .accessibilityHidden(true)
                VStack(spacing: Theme.Spacing.sm) {
                    Text(title)
                        .font(.title2.bold())
                        .accessibilityAddTraits(.isHeader)
                    Text(message)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)
                VStack(spacing: Theme.Spacing.md) { actions }
                #if DEBUG
                if let evalLine {
                    ShareLink("Share eval line", item: evalLine)
                        .font(.footnote)
                }
                #endif
            }
            .padding(Theme.Spacing.xl)
            .frame(maxWidth: 500)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(.background)
    }
}

#Preview("Not food") {
    AnalysisRejectedView(reason: .notFood, onRetake: {}, onFillManually: {})
}

#Preview("People") {
    AnalysisRejectedView(reason: .containsPeople, onRetake: {}, onFillManually: {})
}
