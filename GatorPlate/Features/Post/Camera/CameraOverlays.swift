import SwiftUI

/// Text over the live preview on a solid backing (black at 65%), never glass.
struct CameraOverlayText: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .multilineTextAlignment(.center)
            .foregroundStyle(.white)
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.sm)
            .background(.black.opacity(0.65), in: .capsule)
    }
}

/// Gold ring where the user tapped to focus; fades after a second.
struct CameraFocusRing: View {
    @Binding var point: CGPoint?

    private static let size: CGFloat = 72

    var body: some View {
        if let point {
            Circle()
                .stroke(Theme.Palette.brandGold, lineWidth: 2)
                .frame(width: Self.size, height: Self.size)
                .position(point)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                .task(id: point) {
                    try? await Task.sleep(for: .seconds(1))
                    withAnimation(.easeOut) { self.point = nil }
                }
        }
    }
}

/// A quick white blink on capture; with Reduce Motion, a gentle dim instead.
struct CameraShutterFlash: View {
    let trigger: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let peak = reduceMotion ? 0.25 : 0.6
        Rectangle()
            .fill(reduceMotion ? Color.black : Color.white)
            .keyframeAnimator(initialValue: 0.0, trigger: trigger) { content, opacity in
                content.opacity(opacity)
            } keyframes: { _ in
                CubicKeyframe(peak, duration: 0.05)
                CubicKeyframe(0, duration: reduceMotion ? 0.3 : 0.15)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
