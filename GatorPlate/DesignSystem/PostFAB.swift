import SwiftUI

/// Floating "Post food" button (glass, camera icon) shown bottom-trailing on the Map and Feed.
struct PostFAB: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("Post food", systemImage: "camera.fill")
                .font(.headline)
                .padding(.horizontal, Theme.Spacing.sm)
                .frame(minHeight: Theme.Size.minTapTarget)
        }
        .buttonStyle(.glassProminent)
        .buttonBorderShape(.capsule)
        .tint(Theme.Palette.brandPurple)
        .accessibilityHint("Opens the camera to post leftover food")
    }
}
