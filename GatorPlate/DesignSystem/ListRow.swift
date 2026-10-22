import SwiftUI

/// The one list row used across Settings, posts and the composer: a fixed-width icon, a title (with an optional
/// subtitle under it) and an optional trailing value, so every row lines up whatever its control.
struct ListRow: View {
    let title: String
    let systemImage: String
    var subtitle: String?
    var value: String?
    /// Nil uses the screen's `listAccent`.
    var iconTint: Color?
    /// For buttons that open a sheet, so they look like the navigation rows.
    var showsDisclosure = false

    @ScaledMetric(relativeTo: .body) private var iconWidth: CGFloat = 28
    @Environment(\.listAccent) private var listAccent

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: systemImage)
                .foregroundStyle(iconTint ?? listAccent)
                .frame(width: iconWidth)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                // `Color.primary`, not `.primary`: inside a Button the hierarchical style resolves to the tint.
                Text(title)
                    .foregroundStyle(Color.primary)
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

    @Environment(\.listAccent) private var listAccent

    var body: some View {
        Button(action: action) {
            HStack {
                // Primary text (white in Dark mode), never the button tint.
                Text(title).foregroundStyle(Color.primary)
                Spacer()
                Image(systemName: "checkmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(listAccent)
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

    @Environment(\.listAccent) private var listAccent

    var body: some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: systemImage).foregroundStyle(listAccent)
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .listRowBackground(listAccent.opacity(0.08))
    }
}

#Preview {
    List {
        ListRow(title: "Free food notifications", systemImage: "bell.badge")
        ListRow(title: "Student Center", systemImage: "mappin.and.ellipse", subtitle: "Room 201")
        ListRow(title: "Diet", systemImage: "leaf.fill", value: "Appears vegetarian")
        CheckRow(title: "Vegan", isSelected: true) {}
        NoteRow(text: "AI drafted this post. Give it a quick check.", systemImage: "sparkles")
    }
}
