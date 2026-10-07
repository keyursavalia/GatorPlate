import SwiftUI

/// Marks a field filled by AI. Fields stay fully editable; the badge only shows where values came from.
struct AIBadge: View {
    var body: some View {
        Label("AI", systemImage: "sparkles")
            .font(.caption.weight(.semibold))
            .foregroundStyle(Theme.Palette.brandPurple)
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, 2)
            .background(Theme.Palette.brandPurple.opacity(0.12), in: .capsule)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Filled by AI")
    }
}

#Preview {
    AIBadge()
}
