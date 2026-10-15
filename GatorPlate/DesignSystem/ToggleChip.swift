import SwiftUI

/// Selectable capsule (icon + text). Selected = filled brand tint with a checkmark, so state never relies on color
/// alone; VoiceOver reads the selected trait. Used for allergens, diets, places and alert filters.
struct ToggleChip: View {
    let title: String
    var systemImage: String?
    let isSelected: Bool
    var tint: Color = Theme.Palette.brandPurple
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: isSelected ? "checkmark" : (systemImage ?? "plus"))
                    .font(.caption.weight(.bold))
                    .accessibilityHidden(true)
                Text(title)
                    .font(.subheadline.weight(isSelected ? .semibold : .regular))
                    .multilineTextAlignment(.leading)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .frame(minHeight: Theme.Size.minTapTarget)
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .background(isSelected ? tint : Color.clear, in: .capsule)
            .overlay {
                Capsule().strokeBorder(isSelected ? Color.clear : Color.secondary.opacity(0.5), lineWidth: 1)
            }
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    FlowLayout {
        ToggleChip(title: "Peanuts", systemImage: "exclamationmark.triangle", isSelected: true, tint: .orange) {}
        ToggleChip(title: "Tree nuts", systemImage: "exclamationmark.triangle", isSelected: false) {}
        ToggleChip(title: "Vegan", systemImage: "leaf", isSelected: false) {}
    }
    .padding()
}
