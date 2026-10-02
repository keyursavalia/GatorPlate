import SwiftUI

/// Circular pin with a fork-knife glyph, tinted by dietary class. The selected pin scales up.
struct MapPin: View {
    let dietary: DietaryClass
    let isSelected: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Image(systemName: "fork.knife")
            .font(.subheadline.weight(.bold))
            .foregroundStyle(.white)
            .frame(width: Theme.minTapTarget, height: Theme.minTapTarget)
            .background(dietary.tint, in: Circle())
            .overlay(Circle().strokeBorder(.white, lineWidth: 2))
            .shadow(radius: 2, y: 1)
            .scaleEffect(isSelected ? 1.25 : 1)
            .animation(reduceMotion ? .easeInOut(duration: 0.15) : .spring(duration: 0.3), value: isSelected)
    }
}

#Preview("Pins") {
    HStack(spacing: Theme.Spacing.l) {
        MapPin(dietary: .vegan, isSelected: false)
        MapPin(dietary: .nonVegetarian, isSelected: true)
        MapPin(dietary: .unknown, isSelected: false)
    }
    .padding(Theme.Spacing.xl)
    .environment(\.appEnvironment, .mock)
}
