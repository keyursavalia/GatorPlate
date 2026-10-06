import SwiftUI

/// Map pin: circular fork-knife glyph tinted by diet. Scales up when selected.
struct PostPin: View {
    let dietary: DietaryClass
    let isSelected: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let diameter: CGFloat = 36

    var body: some View {
        Image(systemName: "fork.knife")
            .font(.system(size: diameter * 0.45, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: diameter, height: diameter)
            .background(dietary.tint, in: .circle)
            .overlay(Circle().stroke(.white, lineWidth: 2))
            .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
            .scaleEffect(isSelected && !reduceMotion ? 1.3 : 1)
            .overlay {
                if isSelected && reduceMotion {
                    Circle().stroke(Theme.Palette.brandPurple, lineWidth: 3).padding(-4)
                }
            }
            .animation(reduceMotion ? nil : .spring(duration: 0.3, bounce: 0.4), value: isSelected)
            .frame(minWidth: Theme.Size.minTapTarget, minHeight: Theme.Size.minTapTarget)
            .contentShape(.circle)
    }
}

#Preview {
    HStack {
        PostPin(dietary: .vegan, isSelected: false)
        PostPin(dietary: .nonVegetarian, isSelected: true)
        PostPin(dietary: .mixed, isSelected: false)
    }
    .padding()
}
