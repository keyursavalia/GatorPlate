import SwiftUI

/// Map pin. With a photo: the post's cover in a circle, a ring in the diet color and a small diet badge, so diet
/// never relies on color alone. Without one (or while it loads): the fork-knife glyph on the diet color.
/// Scales up when selected (a ring instead with Reduce Motion).
struct PostPin: View {
    let dietary: DietaryClass
    let isSelected: Bool
    var photo: CGImage?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let glyphDiameter: CGFloat = 36
    private let photoDiameter: CGFloat = 44
    private let badgeDiameter: CGFloat = 18

    var body: some View {
        content
            .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
            .scaleEffect(isSelected && !reduceMotion ? 1.3 : 1)
            .overlay {
                if isSelected && reduceMotion {
                    Circle().stroke(Theme.Palette.accent, lineWidth: 3).padding(-4)
                }
            }
            .animation(reduceMotion ? nil : .spring(duration: 0.3, bounce: 0.4), value: isSelected)
            .frame(minWidth: Theme.Size.minTapTarget, minHeight: Theme.Size.minTapTarget)
            .contentShape(.circle)
    }

    @ViewBuilder
    private var content: some View {
        if let photo {
            Image(decorative: photo, scale: 1)
                .resizable()
                .scaledToFill()
                .frame(width: photoDiameter, height: photoDiameter)
                .clipShape(.circle)
                .overlay(Circle().stroke(dietary.tint, lineWidth: 3))
                .overlay(alignment: .bottomTrailing) { badge.offset(x: 4, y: 4) }
                .transition(.opacity)
        } else {
            Image(systemName: "fork.knife")
                .font(.system(size: glyphDiameter * 0.45, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: glyphDiameter, height: glyphDiameter)
                .background(dietary.tint, in: .circle)
                .overlay(Circle().stroke(.white, lineWidth: 2))
        }
    }

    private var badge: some View {
        Image(systemName: dietary.icon)
            .font(.system(size: badgeDiameter * 0.5, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: badgeDiameter, height: badgeDiameter)
            .background(dietary.tint, in: .circle)
            .overlay(Circle().stroke(.white, lineWidth: 1.5))
    }
}
