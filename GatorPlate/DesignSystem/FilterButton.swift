import SwiftUI

/// The filter control, the same glass circle on the Map and in the Feed toolbar, with a count badge while
/// filters are on. VoiceOver: "Filters, 2 active".
struct FilterButton: View {
    let activeCount: Int
    let action: () -> Void

    @ScaledMetric(relativeTo: .caption2) private var badgeSize: CGFloat = 18

    var body: some View {
        Button(action: action) { icon }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .accessibilityLabel(activeCount == 0 ? "Filters" : "Filters, \(activeCount) active")
            .accessibilityHint("Choose which free food to show")
    }

    private var icon: some View {
        Image(systemName: "line.3.horizontal.decrease")
            .font(.title3)
            .frame(width: Theme.Size.minTapTarget, height: Theme.Size.minTapTarget)
            .overlay(alignment: .topTrailing) {
                if activeCount > 0 {
                    Text(activeCount, format: .number)
                        .font(.caption2.weight(.bold).monospacedDigit())
                        .foregroundStyle(.white)
                        .frame(minWidth: badgeSize, minHeight: badgeSize)
                        .background(Theme.Palette.brandPurple, in: .capsule)
                        .accessibilityHidden(true)
                }
            }
    }
}
