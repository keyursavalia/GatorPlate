import SwiftUI

/// The active filter picks as removable chips ("Vegetarian ✕"). One row that scrolls sideways; at accessibility
/// sizes the chips wrap onto more lines instead, so nothing hides off screen.
struct FilterChips: View {
    let chips: [PostFilterChip]
    let onRemove: (PostFilterChip) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            WrapLayout(spacing: Theme.Spacing.sm, lineSpacing: Theme.Spacing.sm) { chipViews }
        } else {
            ScrollView(.horizontal) {
                HStack(spacing: Theme.Spacing.sm) { chipViews }
            }
            .scrollIndicators(.hidden)
        }
    }

    private var chipViews: some View {
        ForEach(chips, id: \.self) { chip in
            Button {
                onRemove(chip)
            } label: {
                HStack(spacing: Theme.Spacing.xs) {
                    Text(chip.title)
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .accessibilityHidden(true)
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.Palette.brandPurple)
                .padding(.horizontal, Theme.Spacing.md)
                .frame(minHeight: Theme.Size.minTapTarget)
                .background(Theme.Palette.brandPurple.opacity(0.12), in: .capsule)
                .contentShape(.capsule)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(chip.accessibilityLabel)
        }
    }
}

#Preview {
    FilterChips(chips: [.diet(.vegetarian), .place("library"), .timeLeft(10), .allergen(.peanuts)]) { _ in }
        .padding()
}

#Preview("AX5") {
    FilterChips(chips: [.diet(.vegetarian), .place("library"), .timeLeft(10), .allergen(.peanuts)]) { _ in }
        .padding()
        .dynamicTypeSize(.accessibility5)
}
