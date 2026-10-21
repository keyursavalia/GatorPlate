import SwiftUI

/// Icon in a tinted circle, title, message and an optional action. Fills the space it's given and centers itself,
/// so on a `List` use it as an overlay.
struct EmptyState: View {
    let icon: String
    let title: String
    let message: String
    var tint = Theme.Palette.brandPurple
    var actionTitle: String?
    var action: (() -> Void)?

    @ScaledMetric(relativeTo: .largeTitle) private var circle: CGFloat = 88

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: icon)
                .font(.largeTitle.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: circle, height: circle)
                .background(tint.opacity(0.15), in: .circle)
                .overlay { Circle().strokeBorder(tint.opacity(0.25), lineWidth: 1) }
                .accessibilityHidden(true)
            VStack(spacing: Theme.Spacing.sm) {
                Text(title).font(.title2.bold())
                    .accessibilityAddTraits(.isHeader)
                Text(message).font(.body).foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
            if let actionTitle, let action {
                PrimaryButton(title: actionTitle, action: action)
            }
        }
        .padding(Theme.Spacing.xl)
        .frame(maxWidth: 420)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
    }
}

#Preview {
    EmptyState(icon: "fork.knife", title: "No free food yet",
               message: "New posts show up here.", actionTitle: "Post food") {}
}

#Preview("Tinted, AX5") {
    EmptyState(icon: "checkmark.shield", title: "All clear", message: "No reports in the last 90 days.",
               tint: Theme.Palette.success)
        .dynamicTypeSize(.accessibility5)
}
