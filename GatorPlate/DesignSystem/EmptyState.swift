import SwiftUI

/// Icon, title, message and an optional action.
struct EmptyState: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundStyle(Theme.Palette.brandPurple)
                .accessibilityHidden(true)
            VStack(spacing: Theme.Spacing.sm) {
                Text(title).font(.title2.bold())
                Text(message).font(.body).foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
            if let actionTitle, let action {
                PrimaryButton(title: actionTitle, action: action)
            }
        }
        .padding(Theme.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
    }
}

#Preview {
    EmptyState(icon: "fork.knife", title: "No free food yet",
               message: "New posts show up here.", actionTitle: "Post food") {}
}
