import SwiftUI

/// Icon + primary + secondary text, for location, poster and similar facts. One VoiceOver element.
struct InfoRow<Leading: View>: View {
    let primary: String
    var secondary: String?
    @ViewBuilder var leading: Leading

    var body: some View {
        HStack(alignment: .center, spacing: Theme.Spacing.md) {
            leading
                .frame(minWidth: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(primary)
                    .font(.subheadline.weight(.semibold))
                if let secondary, !secondary.isEmpty {
                    Text(secondary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

extension InfoRow where Leading == AnyView {
    init(systemImage: String, primary: String, secondary: String? = nil) {
        self.init(primary: primary, secondary: secondary) {
            AnyView(Image(systemName: systemImage)
                .font(.body)
                .foregroundStyle(Theme.Palette.brandPurple))
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
        InfoRow(systemImage: "mappin.and.ellipse", primary: "Student Services Building", secondary: "Room 201")
        InfoRow(primary: "Asian Student Union", secondary: "Organization") { MonogramAvatar(name: "Asian Student Union") }
    }
    .padding()
}
