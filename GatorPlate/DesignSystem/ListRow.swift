import SwiftUI

/// The one list row used across Settings, posts and the composer: a fixed-width icon, a title (with an optional
/// subtitle under it) and an optional trailing value, so every row lines up whatever its control.
struct ListRow: View {
    let title: String
    let systemImage: String
    var subtitle: String?
    var value: String?
    var iconTint: Color = Theme.Palette.brandPurple
    /// For buttons that open a sheet, so they look like the navigation rows.
    var showsDisclosure = false

    @ScaledMetric(relativeTo: .body) private var iconWidth: CGFloat = 28

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: systemImage)
                .foregroundStyle(iconTint)
                .frame(width: iconWidth)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundStyle(.primary)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: Theme.Spacing.sm)
            if let value {
                Text(value)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
            }
            if showsDisclosure {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// A list row that toggles a checkmark (alert filters, allergens). VoiceOver reads the selected trait.
struct CheckRow: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title).foregroundStyle(.primary)
                Spacer()
                Image(systemName: "checkmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.Palette.brandPurple)
                    .opacity(isSelected ? 1 : 0)
                    .accessibilityHidden(true)
            }
            .contentShape(.rect)
        }
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Small tinted note row (AI drafted, photos left out, "confirm with the host").
struct NoteRow: View {
    let text: String
    let systemImage: String

    var body: some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: systemImage).foregroundStyle(Theme.Palette.brandPurple)
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .listRowBackground(Theme.Palette.brandPurple.opacity(0.08))
    }
}

#Preview {
    List {
        ListRow(title: "Free food notifications", systemImage: "bell.badge")
        ListRow(title: "Cesar Chavez Center", systemImage: "mappin.and.ellipse", subtitle: "Room 201")
        ListRow(title: "Diet", systemImage: "leaf.fill", value: "Appears vegetarian")
        CheckRow(title: "Vegan", isSelected: true) {}
        NoteRow(text: "AI drafted this post. Give it a quick check.", systemImage: "sparkles")
    }
}
