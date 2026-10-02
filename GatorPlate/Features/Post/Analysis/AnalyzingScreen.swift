import SwiftUI

/// Step 2 of the post flow: the photo with a progress indicator and a rotating status line.
/// Cancel and "Fill it in myself" stay visible the whole time.
struct AnalyzingScreen: View {
    let photo: CapturedPhoto
    let statusMessage: String
    let isTakingLong: Bool
    let onCancel: () -> Void
    let onManual: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shimmerPhase: CGFloat = -1

    var body: some View {
        VStack(spacing: Theme.Spacing.l) {
            Image(uiImage: photo.previewImage)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.photo))
                .overlay { shimmer }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityLabel("Your photo, being analyzed")

            VStack(spacing: Theme.Spacing.s) {
                ProgressView()
                Text(statusMessage)
                    .font(.headline)
                if isTakingLong {
                    Text("Still working...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .multilineTextAlignment(.center)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.updatesFrequently)

            VStack(spacing: Theme.Spacing.s) {
                Button("Fill it in myself", action: onManual)
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: Theme.buttonHeight)
                    .background(Color.surfaceSecondary, in: RoundedRectangle(cornerRadius: Theme.Radius.button))
                Button("Cancel", role: .cancel, action: onCancel)
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: Theme.minTapTarget)
            }
        }
        .padding(Theme.Spacing.l)
        .background(Color.surface.ignoresSafeArea())
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) { shimmerPhase = 1.5 }
        }
    }

    @ViewBuilder
    private var shimmer: some View {
        if !reduceMotion {
            GeometryReader { proxy in
                LinearGradient(
                    colors: [.clear, .white.opacity(0.25), .clear],
                    startPoint: .leading, endPoint: .trailing
                )
                .frame(width: proxy.size.width * 0.5)
                .offset(x: proxy.size.width * shimmerPhase)
            }
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.photo))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}

#Preview("Analyzing") {
    AnalyzingScreen(
        photo: PreviewSupport.photo(variant: 1), statusMessage: "Identifying food...",
        isTakingLong: false, onCancel: {}, onManual: {}
    )
    .environment(\.appEnvironment, .mock)
}

#Preview("Analyzing, slow") {
    AnalyzingScreen(
        photo: PreviewSupport.photo(variant: 2), statusMessage: "Writing your post...",
        isTakingLong: true, onCancel: {}, onManual: {}
    )
    .environment(\.appEnvironment, .mock)
}
