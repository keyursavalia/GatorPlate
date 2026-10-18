import SwiftUI

/// Outlined brand capsule, the companion to `PrimaryButton` (e.g. "Join now" + "Sign in").
struct SecondaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: Theme.Size.primaryButtonHeight)
                .padding(.horizontal, Theme.Spacing.lg)
                .foregroundStyle(Theme.Palette.brandPurple)
                .overlay { Capsule().strokeBorder(Theme.Palette.brandPurple, lineWidth: 1.5) }
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

/// Filled red capsule for destructive actions (sign out, delete account), with a loading state.
struct DestructiveButton: View {
    let title: String
    var isLoading = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Text(title)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .opacity(isLoading ? 0 : 1)
                if isLoading {
                    ProgressView().tint(.white)
                }
            }
            .frame(maxWidth: .infinity, minHeight: Theme.Size.primaryButtonHeight)
            .padding(.horizontal, Theme.Spacing.lg)
            .foregroundStyle(.white)
            .background(Theme.Palette.danger, in: .capsule)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .accessibilityLabel(title)
        .accessibilityValue(isLoading ? "Loading" : "")
    }
}

#Preview {
    VStack(spacing: Theme.Spacing.lg) {
        PrimaryButton(title: "Join now") {}
        SecondaryButton(title: "Sign in") {}
        DestructiveButton(title: "Sign out") {}
        DestructiveButton(title: "Delete account", isLoading: true) {}
    }
    .padding()
}
