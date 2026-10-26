import SwiftUI

/// Centered over the map when a tapped alert's post is gone: hard to miss, says why, and offers the Feed.
/// Solid (not glass) because it carries text. Announced to VoiceOver; hides after
/// `AppConfig.alertUnavailableCardSeconds`, but never while VoiceOver focus is on it.
struct UnavailableCard: View {
    let onShowAvailable: () -> Void
    let onDismiss: () -> Void

    @AccessibilityFocusState private var isFocused: Bool
    @State private var hasElapsed = false
    @State private var hasAppeared = false

    private static let title = "This food is no longer available"
    private static let message = "It was picked up or its time ran out."

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: "clock.badge.xmark")
                .font(.system(size: 44))
                .foregroundStyle(Theme.Palette.warning)
                .accessibilityHidden(true)
            VStack(spacing: Theme.Spacing.sm) {
                Text(Self.title)
                    .font(.title3.weight(.bold))
                    .accessibilityAddTraits(.isHeader)
                Text(Self.message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
            VStack(spacing: Theme.Spacing.sm) {
                PrimaryButton(title: "See what's available", action: onShowAvailable)
                Button("OK", action: onDismiss)
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: Theme.Size.minTapTarget)
            }
        }
        .padding(Theme.Spacing.xl)
        .frame(maxWidth: 360)
        .background(.background, in: .rect(cornerRadius: Theme.Radius.card))
        .shadow(color: .black.opacity(0.2), radius: 20, y: 8)
        .padding(Theme.Spacing.xl)
        .accessibilityElement(children: .contain)
        .accessibilityFocused($isFocused)
        .sensoryFeedback(.warning, trigger: hasAppeared) { _, appeared in appeared }
        .task {
            hasAppeared = true
            AccessibilityNotification.Announcement("\(Self.title). \(Self.message)").post()
            try? await Task.sleep(for: .seconds(AppConfig.alertUnavailableCardSeconds))
            guard !Task.isCancelled else { return }
            hasElapsed = true
            if !isFocused { onDismiss() }
        }
        .onChange(of: isFocused) { _, focused in
            if !focused, hasElapsed { onDismiss() }
        }
    }
}
