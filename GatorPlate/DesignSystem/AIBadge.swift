import SwiftUI

/// Marks AI-generated content. Always paired with text so it never relies on the icon alone.
struct AIBadge: View {
    var text = "AI draft, please review"

    var body: some View {
        Label(text, systemImage: "sparkles")
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.brandPurple)
            .padding(.horizontal, Theme.Spacing.m)
            .padding(.vertical, Theme.Spacing.xs + 2)
            .background(Color.brandPurple.opacity(0.12), in: Capsule())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(text)
    }
}

#Preview("AI badge") {
    AIBadge()
        .padding()
        .environment(\.appEnvironment, .mock)
}
