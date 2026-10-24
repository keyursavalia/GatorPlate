import SwiftUI

/// Bold condensed uppercase title with a one-line subtitle, centered. Used by the entry and account screens.
struct AuthHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Text(title)
                .font(.largeTitle.weight(.heavy).width(.condensed))
                .textCase(.uppercase)
                .accessibilityAddTraits(.isHeader)
            Text(subtitle)
                .font(.body)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }
}

/// Small uppercase brand-colored text button ("Forgot password", "Create account").
struct AuthTextButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .tracking(0.6)
                .textCase(.uppercase)
                .foregroundStyle(Theme.Palette.brandPurple)
                .frame(minHeight: Theme.Size.minTapTarget)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}
