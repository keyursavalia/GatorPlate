#if DEBUG
import SwiftUI

/// DEBUG only (Settings > Developer > Map bounds overlay): proves the north-edge limit on device.
/// Green when the visible north edge is at or below the limit (within tolerance), red otherwise.
struct MapBoundsHUD: View {
    let viewport: ViewportReadout

    var body: some View {
        Label(text, systemImage: viewport.isWithinLimit ? "checkmark.circle.fill" : "xmark.octagon.fill")
            .font(.caption.monospacedDigit().weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.xs)
            // Solid: text over the map.
            .background(viewport.isWithinLimit ? Color.green.opacity(0.85) : Color.red.opacity(0.85), in: .capsule)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Map bounds \(viewport.isWithinLimit ? "OK" : "exceeded"): \(text)")
    }

    private var text: String {
        let edge = viewport.northEdge.formatted(.number.precision(.fractionLength(4)))
        let limit = SFSUCampus.northVisibleLimit.formatted(.number.precision(.fractionLength(4)))
        let heading = Int(viewport.heading.rounded())
        return "N edge \(edge) · limit \(limit) · \(Int(viewport.distance.rounded())) m · \(heading)°"
    }
}

#Preview {
    VStack {
        MapBoundsHUD(viewport: ViewportReadout(northEdge: 37.7306, distance: 2800, heading: 45))
        MapBoundsHUD(viewport: ViewportReadout(northEdge: 37.7330, distance: 2800, heading: 90))
    }
}
#endif
