import SwiftUI

/// Small vertical tile: a value over a caption ("24 min" / "left"). Grouped into one VoiceOver element.
struct StatTile: View {
    let value: String
    let caption: String
    var systemImage: String?
    var tint: Color = .primary

    var body: some View {
        VStack(spacing: Theme.Spacing.xs) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.subheadline)
                    .foregroundStyle(tint)
                    .accessibilityHidden(true)
            }
            Text(value)
                .font(.headline)
                .foregroundStyle(tint)
                .multilineTextAlignment(.center)
            Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: Theme.Size.minTapTarget)
        .padding(.vertical, Theme.Spacing.sm)
        .padding(.horizontal, Theme.Spacing.xs)
        .background(.background.secondary, in: .rect(cornerRadius: Theme.Radius.field))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(value) \(caption)")
    }
}

#Preview {
    HStack {
        StatTile(value: "24 min", caption: "left", systemImage: "clock")
        StatTile(value: "4 min", caption: "walk", systemImage: "figure.walk")
        StatTile(value: "~30", caption: "servings", systemImage: "takeoutbag.and.cup.and.straw")
    }
    .padding()
}
