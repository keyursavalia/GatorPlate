import SwiftUI

/// Post flow step 2: a fanned stack of the photos with a purple scan line, then the steps as a timeline in a card,
/// so it reads as progress rather than waiting. "Fill it in myself" and Cancel stay pinned at the bottom.
struct AnalyzingScreen: View {
    let viewModel: AnalysisViewModel
    let onCancel: () -> Void
    let onFillManually: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scanOffset: CGFloat = 0

    private static let photoSize: CGFloat = 240

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.xl) {
                photoStack
                    .padding(.top, Theme.Spacing.lg)

                VStack(spacing: Theme.Spacing.xs) {
                    Text("Drafting your post")
                        .font(.title2.bold())
                        .accessibilityAddTraits(.isHeader)
                    Text(viewModel.isSlow ? "Still working…" : "This takes a few seconds.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .contentTransition(.opacity)
                }
                .multilineTextAlignment(.center)

                timeline

                Label {
                    Text("AI drafts it. You review everything before it's posted.")
                } icon: {
                    Image(systemName: "sparkles").foregroundStyle(Theme.Palette.brandPurple)
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(Theme.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.Palette.brandPurple.opacity(0.08), in: .rect(cornerRadius: Theme.Radius.field))
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.bottom, Theme.Spacing.lg)
            .frame(maxWidth: 500)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom) { actions }
        .background(.background)
        .animation(reduceMotion ? nil : .easeInOut, value: viewModel.isSlow)
    }

    private var actions: some View {
        VStack(spacing: Theme.Spacing.sm) {
            SecondaryButton(title: "Fill it in myself", action: onFillManually)
                .accessibilityHint("Stops the AI and lets you write the post")
            Button("Cancel", role: .cancel, action: onCancel)
                .font(.body.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: Theme.Size.minTapTarget)
                .accessibilityHint("Stops the AI and goes back to your photos")
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.top, Theme.Spacing.md)
        .frame(maxWidth: 500)
        .frame(maxWidth: .infinity)
        .background(.background)
    }

    // MARK: Photos

    private var photoStack: some View {
        let photos = Array(viewModel.photos.prefix(4))
        return ZStack {
            ForEach(Array(photos.enumerated().reversed()), id: \.element.id) { index, photo in
                Image(uiImage: photo.previewImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: Self.photoSize, height: Self.photoSize)
                    .overlay { if index == 0, !reduceMotion { scanLine } }
                    .clipShape(.rect(cornerRadius: Theme.Radius.photo))
                    .overlay {
                        RoundedRectangle(cornerRadius: Theme.Radius.photo).strokeBorder(.background, lineWidth: 3)
                    }
                    .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
                    .rotationEffect(.degrees(fanAngle(index: index, count: photos.count)))
                    .offset(x: fanOffset(index: index, count: photos.count))
            }
        }
        .frame(height: Self.photoSize + 30)
        .overlay(alignment: .bottom) {
            Label("AI drafting", systemImage: "sparkles")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, 6)
                // Solid: pills over photos never use glass.
                .background(Theme.Palette.brandPurple, in: .capsule)
                .shadow(color: Theme.Palette.brandPurple.opacity(0.4), radius: 8, y: 4)
                .symbolEffect(.pulse, options: .repeat(.continuous), isActive: !reduceMotion)
                .offset(y: Theme.Spacing.sm)
        }
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

    /// A brand-purple line with a soft glow sweeping down the top photo.
    private var scanLine: some View {
        GeometryReader { proxy in
            LinearGradient(colors: [Theme.Palette.brandPurple.opacity(0), Theme.Palette.brandPurple.opacity(0.45)],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: proxy.size.height * 0.35)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Theme.Palette.brandPurple)
                        .frame(height: 2)
                        .shadow(color: Theme.Palette.brandPurple, radius: 6)
                }
                .offset(y: scanOffset * proxy.size.height - proxy.size.height * 0.35)
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { scanOffset = 1 }
                }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: Timeline

    /// The steps in a card: a marker per step joined by a line that turns purple as steps finish.
    private var timeline: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(viewModel.steps.enumerated()), id: \.offset) { index, step in
                stepRow(step, index: index, isLast: index == viewModel.steps.count - 1)
            }
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: .rect(cornerRadius: Theme.Radius.card))
    }

    private func stepRow(_ title: String, index: Int, isLast: Bool) -> some View {
        let isDone = index < viewModel.completedSteps
        let isCurrent = index == viewModel.completedSteps
        return HStack(alignment: .top, spacing: Theme.Spacing.md) {
            VStack(spacing: 0) {
                StepMarker(isDone: isDone, isCurrent: isCurrent)
                if !isLast {
                    Capsule()
                        .fill(isDone ? AnyShapeStyle(Theme.Palette.brandPurple) : AnyShapeStyle(.quaternary))
                        .frame(width: 2)
                        .frame(minHeight: Theme.Spacing.lg)
                        .padding(.vertical, Theme.Spacing.xs)
                }
            }
            .frame(width: 28)
            .accessibilityHidden(true)
            Text(isCurrent ? "\(title)…" : title)
                .font(isCurrent ? .headline : .body)
                .foregroundStyle(isDone || isCurrent ? .primary : .secondary)
                .frame(minHeight: 28)
                .padding(.bottom, isLast ? 0 : Theme.Spacing.sm)
            Spacer(minLength: 0)
        }
        .animation(reduceMotion ? nil : .easeInOut, value: isDone)
        .animation(reduceMotion ? nil : .easeInOut, value: isCurrent)
        .accessibilityElement(children: .combine)
        .accessibilityValue(isDone ? "Done" : (isCurrent ? "In progress" : "Waiting"))
    }
}

/// A step's marker: a purple check (drawn on) when done, a pulsing purple ring while current, a gray ring after.
private struct StepMarker: View {
    let isDone: Bool
    let isCurrent: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPulsing = false

    var body: some View {
        ZStack {
            if isDone {
                let check = Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Theme.Palette.brandPurple)
                if reduceMotion {
                    check.transition(.opacity)
                } else {
                    check.transition(.symbolEffect(.drawOn))
                }
            } else if isCurrent {
                Circle()
                    .strokeBorder(Theme.Palette.brandPurple, lineWidth: 2)
                    .overlay {
                        Circle()
                            .fill(Theme.Palette.brandPurple)
                            .padding(7)
                            .scaleEffect(isPulsing ? 1 : 0.6)
                            .opacity(isPulsing ? 1 : 0.5)
                    }
                    .onAppear {
                        guard !reduceMotion else { isPulsing = true; return }
                        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { isPulsing = true }
                    }
            } else {
                Circle().strokeBorder(.tertiary, lineWidth: 2)
            }
        }
        .frame(width: 24, height: 24)
        .frame(width: 28, height: 28)
    }
}

