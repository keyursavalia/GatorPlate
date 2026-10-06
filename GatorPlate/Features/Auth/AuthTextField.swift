import SwiftUI

enum AuthFocusField: Hashable {
    case name, email, password
}

/// Label above a field, tappable area of at least 44 pt, and an inline error with icon and text.
struct AuthTextField<Content: View>: View {
    let label: String
    var error: String?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            content
                .padding(.horizontal, Theme.Spacing.md)
                .frame(minHeight: Theme.Size.minTapTarget)
                .background(.quaternary, in: .rect(cornerRadius: Theme.Radius.field))
            if let error {
                Label {
                    Text(error).font(.caption)
                } icon: {
                    Image(systemName: "exclamationmark.circle.fill").foregroundStyle(Theme.Palette.danger)
                }
                .accessibilityLabel("Error: \(error)")
            }
        }
    }
}
