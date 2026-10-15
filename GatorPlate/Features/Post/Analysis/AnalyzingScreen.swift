import SwiftUI

/// Post flow step 2: a fanned stack of the photos with a shimmer and a step checklist, so it reads as progress
/// rather than waiting. Cancel and the manual path are always visible.
struct AnalyzingScreen: View {
    let viewModel: AnalysisViewModel
    let onCancel: () -> Void
    let onFillManually: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shimmerOffset: CGFloat = -1

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.xl) {
                photoStack
                    .padding(.top, Theme.Spacing.lg)

                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    Text("Drafting your post")
                        .font(.title2.bold())
                        .frame(maxWidth: .infinity)
                        .accessibilityAddTraits(.isHeader)
                    ForEach(Array(viewModel.steps.enumerated()), id: \.offset) { index, step in
                        stepRow(step, index: index)
                    }
                    if viewModel.isSlow {
                        Text("Still working…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .transition(.opacity)
                    }
                    Text("AI drafts it. You review everything before it's posted.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: 360)

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
                        .accessibilityHint("Stops the AI and goes back to your photos")
                }
            }
            .padding(Theme.Spacing.lg)
            .frame(maxWidth: 500)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(.background)
        .animation(reduceMotion ? nil : .easeInOut, value: viewModel.isSlow)
    }

    // MARK: Photos

    private var photoStack: some View {
        let photos = Array(viewModel.photos.prefix(4))
        return ZStack {
            ForEach(Array(photos.enumerated().reversed()), id: \.element.id) { index, photo in
                Image(uiImage: photo.previewImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 200, height: 200)
                    .overlay { if index == 0, !reduceMotion { shimmer } }
                    .clipShape(.rect(cornerRadius: Theme.Radius.photo))
                    .overlay {
                        RoundedRectangle(cornerRadius: Theme.Radius.photo).strokeBorder(.background, lineWidth: 3)
                    }
                    .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
                    .rotationEffect(.degrees(fanAngle(index: index, count: photos.count)))
                    .offset(x: fanOffset(index: index, count: photos.count))
            }
        }
        .frame(height: 230)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(photos.count == 1 ? "Your food photo, being analyzed"
                                              : "Your \(photos.count) food photos, being analyzed")
    }

    private func fanAngle(index: Int, count: Int) -> Double {
        guard count > 1 else { return 0 }
        return (Double(index) - Double(count - 1) / 2) * 6
    }

    private func fanOffset(index: Int, count: Int) -> CGFloat {
        guard count > 1 else { return 0 }
        return (CGFloat(index) - CGFloat(count - 1) / 2) * 18
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

    // MARK: Checklist

    private func stepRow(_ title: String, index: Int) -> some View {
        let isDone = index < viewModel.completedSteps
        let isCurrent = index == viewModel.completedSteps
        return HStack(spacing: Theme.Spacing.md) {
            ZStack {
                if isDone {
                    let check = Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.Palette.success)
                    if reduceMotion {
                        check.transition(.opacity)
                    } else {
                        check.transition(.symbolEffect(.drawOn))
                    }
                } else if isCurrent {
                    ProgressView()
                } else {
                    Image(systemName: "circle")
                        .foregroundStyle(.tertiary)
                }
            }
            .font(.title3)
            .frame(width: 28)
            .accessibilityHidden(true)
            Text(isCurrent ? "\(title)…" : title)
                .font(isCurrent ? .headline : .body)
                .foregroundStyle(isDone || isCurrent ? .primary : .secondary)
        }
        .animation(reduceMotion ? nil : .easeInOut, value: isDone)
        .accessibilityElement(children: .combine)
        .accessibilityValue(isDone ? "Done" : (isCurrent ? "In progress" : "Waiting"))
    }
}
