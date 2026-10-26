import SwiftUI

/// Over the map while filters hide posts: "Filtered · 3 of 7" (tap opens the filters, ✕ clears them), or
/// "No posts match your filters" with Clear, so a filtered map never looks broken.
struct FilterPill: View {
    let shown: Int
    let total: Int
    let onOpen: () -> Void
    let onClear: () -> Void

    var body: some View {
        GlassEffectContainer(spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.sm) {
                Button(action: onOpen) {
                    Label(title, systemImage: "line.3.horizontal.decrease")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, Theme.Spacing.xs)
                        .frame(minHeight: Theme.Size.minTapTarget)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.capsule)
                .accessibilityLabel(spokenTitle)
                .accessibilityHint("Opens the filters")

                if shown == 0 {
                    Button("Clear", action: onClear)
                        .font(.subheadline.weight(.semibold))
                        .frame(minHeight: Theme.Size.minTapTarget)
                        .buttonStyle(.glassProminent)
                        .buttonBorderShape(.capsule)
                        .tint(Theme.Palette.brandPurple)
                        .accessibilityLabel("Clear filters")
                } else {
                    Button("Clear filters", systemImage: "xmark", action: onClear)
                        .labelStyle(.iconOnly)
                        .font(.subheadline.weight(.semibold))
                        .frame(width: Theme.Size.minTapTarget, height: Theme.Size.minTapTarget)
                        .buttonStyle(.glass)
                        .buttonBorderShape(.circle)
                }
            }
        }
    }

    private var title: String {
        shown == 0 ? "No posts match your filters" : "Filtered · \(shown) of \(total)"
    }

    private var spokenTitle: String {
        shown == 0 ? "No posts match your filters" : "Filtered, showing \(shown) of \(total) posts"
    }
}
