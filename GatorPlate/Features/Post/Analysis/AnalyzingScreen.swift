import SwiftUI

/// Post flow step 2: a fanned stack of the photos with a purple scan line, then the steps as a timeline in a card,
/// so it reads as progress rather than waiting. "Fill it in myself" and Cancel stay pinned at the bottom.
struct AnalyzingScreen: View {
    let viewModel: AnalysisViewModel
    let onCancel: () -> Void
    let onFillManually: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
        let count = min(viewModel.photos.count, 4)
        return AnalysisPhotoStack(photos: viewModel.photos, isScanning: true,
                                  accessibilityLabel: count == 1 ? "Your food photo, being analyzed"
                                                                 : "Your \(count) food photos, being analyzed") {
            AnalysisStatusPill(title: "AI drafting", systemImage: "sparkles", tint: Theme.Palette.brandPurple)
                .symbolEffect(.pulse, options: .repeat(.continuous), isActive: !reduceMotion)
        }
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

