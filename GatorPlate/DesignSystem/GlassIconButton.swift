import SwiftUI

/// Floating circular map control with the Liquid Glass button style. 44 pt minimum.
struct GlassIconButton: View {
    let systemImage: String
    let accessibilityLabel: String
    var accessibilityHint = ""
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title3)
                .frame(width: Theme.Size.minTapTarget, height: Theme.Size.minTapTarget)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
    }
}
