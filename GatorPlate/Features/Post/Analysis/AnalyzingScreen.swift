import SwiftUI

/// Post flow step 2: the photo with a shimmer and a rotating status line. Cancel and the manual path are always visible.
struct AnalyzingScreen: View {
    let viewModel: AnalysisViewModel
    let onCancel: () -> Void
    let onFillManually: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shimmerOffset: CGFloat = -1

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.xl) {
                photo

                VStack(spacing: Theme.Spacing.md) {
                    ProgressView()
                        .accessibilityHidden(true)
                    Text(viewModel.statusMessage)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .contentTransition(.opacity)
                        .animation(reduceMotion ? nil : .easeInOut, value: viewModel.statusMessage)
                        .accessibilityAddTraits(.updatesFrequently)
                    Text("AI drafts your post. You review everything before it's published.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: Theme.Spacing.md) {
                    Button(action: onFillManually) {
                        Text("Fill it in myself")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: Theme.Size.primaryButtonHeight)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .tint(Theme.Palette.brandPurple)
                    .accessibilityHint("Stops the AI and lets you write the post")

                    Button("Cancel", role: .cancel, action: onCancel)
                        .frame(minHeight: Theme.Size.minTapTarget)
                        .accessibilityHint("Stops the AI and goes back to the photo")
                }
            }
            .padding(Theme.Spacing.lg)
            .frame(maxWidth: 500)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(.background)
    }

    private var photo: some View {
        Image(uiImage: viewModel.photo.previewImage)
            .resizable()
            .scaledToFit()
            .overlay { if !reduceMotion { shimmer } }
            .clipShape(.rect(cornerRadius: Theme.Radius.photo))
            .frame(maxHeight: 360)
            .accessibilityLabel("Your food photo, being analyzed")
    }

    private var shimmer: some View {
        GeometryReader { proxy in
            LinearGradient(colors: [.clear, .white.opacity(0.35), .clear], startPoint: .leading, endPoint: .trailing)
                .frame(width: proxy.size.width * 0.6)
                .offset(x: shimmerOffset * proxy.size.width)
                .onAppear {
                    withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) { shimmerOffset = 1.4 }
                }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
