import SwiftUI

/// Shown when the guest session couldn't start or the profile couldn't be loaded.
struct AuthErrorView: View {
    let message: String
    let onRetry: () -> Void
    let onSignOut: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            EmptyState(icon: "exclamationmark.triangle.fill", title: "Couldn't connect",
                       message: message, actionTitle: "Try again", action: onRetry)
            Button("Start over as a guest", role: .destructive, action: onSignOut)
                .frame(minHeight: Theme.Size.minTapTarget)
                .padding(.bottom, Theme.Spacing.xl)
        }
    }
}

#Preview {
    AuthErrorView(message: "No connection. Check your internet and try again.", onRetry: {}, onSignOut: {})
}
