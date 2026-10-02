import SwiftUI

/// Floating "Post food" button. Glass is for controls like this one, never for content.
struct PostFAB: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("Post food", systemImage: "camera.fill")
                .font(.headline)
                .frame(minHeight: Theme.minTapTarget)
                .padding(.horizontal, Theme.Spacing.s)
        }
        .buttonStyle(.glassProminent)
        .tint(.brandPurple)
        .accessibilityLabel("Post food")
        .accessibilityHint("Opens the camera to photograph leftover food")
    }
}

#Preview("Post FAB") {
    PostFAB {}
        .padding()
        .environment(\.appEnvironment, .mock)
}
