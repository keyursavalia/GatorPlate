import SwiftUI

/// Outlined brand capsule, the companion to `PrimaryButton` (e.g. "Join now" + "Sign in").
struct SecondaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .multilineTextAlignment(.center)
        }
        .buttonStyle(.secondaryCapsule)
        .accessibilityLabel(title)
    }
}

/// `SecondaryButton`'s look as a style, for buttons that aren't a plain `Button` (e.g. a `PhotosPicker`), so they
/// match `PrimaryButton`'s size.
struct SecondaryCapsuleButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: Theme.Size.primaryButtonHeight)
            .padding(.horizontal, Theme.Spacing.lg)
            .foregroundStyle(Theme.Palette.brandPurple)
            .overlay { Capsule().strokeBorder(Theme.Palette.brandPurple, lineWidth: 1.5) }
            .contentShape(.capsule)
            .opacity(configuration.isPressed ? 0.6 : isEnabled ? 1 : 0.4)
    }
}

extension ButtonStyle where Self == SecondaryCapsuleButtonStyle {
    static var secondaryCapsule: SecondaryCapsuleButtonStyle { SecondaryCapsuleButtonStyle() }
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
