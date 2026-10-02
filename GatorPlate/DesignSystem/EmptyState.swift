import SwiftUI

/// Icon, title, message, and an optional action.
struct EmptyState: View {
    let systemImage: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: Theme.Spacing.m) {
            Image(systemName: systemImage)
                .font(.largeTitle)
                .foregroundStyle(Color.brandPurple)
                .accessibilityHidden(true)

            Text(title)
                .font(.title2.bold())

            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)

            if let actionTitle, let action {
                PrimaryButton(title: actionTitle, action: action)
                    .padding(.top, Theme.Spacing.s)
            }
        }
        .multilineTextAlignment(.center)
        .padding(Theme.Spacing.xl)
        .frame(maxWidth: .infinity)
    }
}

#Preview("With action") {
    EmptyState(
        systemImage: "fork.knife",
        title: "No free food right now",
        message: "Check back soon, or post some yourself.",
        actionTitle: "Post food"
    ) {}
    .environment(\.appEnvironment, .mock)
}

#Preview("No action") {
    EmptyState(
        systemImage: "fork.knife",
        title: "No free food right now",
        message: "Check back soon."
    )
    .environment(\.appEnvironment, .mock)
}
