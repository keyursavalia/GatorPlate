import SwiftUI

/// Welcome screen features as swipeable cards (the next one peeks in from the side). Advances on its own every few
/// seconds, with the active page dot filling up as a timer, until the person swipes or taps a dot; then it stays
/// where they put it. No auto-advance with Reduce Motion or VoiceOver. Every card is the same height.
struct WelcomeFeatureCarousel: View {
    struct Feature: Identifiable {
        let id: String
        let icon: String
        let title: String
        let detail: String
        let tags: [String]
        let tint: Color
    }

    static let features = [
        Feature(id: "map", icon: "map.fill", title: "Live campus map",
                detail: "See free food on campus right now. No account needed.",
                tags: ["Live", "No sign-up"], tint: Theme.Palette.success),
        Feature(id: "ai", icon: "camera.viewfinder", title: "Snap it, AI drafts it",
                detail: "Gemini fills in the food, diet and allergens from a photo. You check it before it posts.",
                tags: ["Food", "Diet", "Allergens"], tint: Theme.Palette.accent),
        Feature(id: "alerts", icon: "bell.badge.fill", title: "Alerts you choose",
                detail: "Get notified only for the food and places you care about.",
                tags: ["Diet", "Places", "Quiet hours"], tint: Theme.Palette.brandPurple),
        Feature(id: "safety", icon: "exclamationmark.shield.fill", title: "Eat smart",
                detail: "Eat at your own risk and ask about allergens. Report or block anything that's off.",
                tags: ["Posts end within an hour", "Report", "Block"], tint: Theme.Palette.warning),
        Feature(id: "privacy", icon: "lock.shield.fill", title: "Private by design",
                detail: "Your location stays on your phone. Your data is never sold.",
                tags: ["No ads", "No tracking"], tint: Theme.Palette.brandGold),
    ]

    /// Seconds each card shows before the next.
    private static let beatSeconds = 4.5
    private static let settleSeconds = 0.4

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @State private var current: Feature.ID? = Self.features.first?.id
    /// Set once the person swipes or taps a dot: from then on the carousel doesn't move by itself.
    @State private var userTookOver = false
    /// The active dot's timer fill, 0...1.
    @State private var progress: CGFloat = 0

    private var autoAdvances: Bool { !reduceMotion && !voiceOverEnabled && !userTookOver }

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            ScrollView(.horizontal) {
                HStack(spacing: Theme.Spacing.md) {
                    ForEach(Self.features) { feature in
                        FeatureCard(feature: feature)
                            .containerRelativeFrame(.horizontal)
                            .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                                content
                                    .scaleEffect(phase.isIdentity || reduceMotion ? 1 : 0.94)
                                    .opacity(phase.isIdentity ? 1 : 0.55)
                            }
                    }
                }
                // Every card as tall as the tallest.
                .fixedSize(horizontal: false, vertical: true)
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, Theme.Spacing.xxl, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $current)
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
            .onScrollPhaseChange { _, phase in
                if phase == .interacting { userTookOver = true }
            }
            pageDots
        }
        .task(id: TimerKey(current: current, autoAdvances: autoAdvances)) { await advanceAfterBeat() }
    }

    /// One dot per card; the active one is a capsule that fills as its timer runs. Tapping a dot shows that card.
    /// Hidden from VoiceOver, which reaches every card by swiping.
    private var pageDots: some View {
        HStack(spacing: Theme.Spacing.sm) {
            ForEach(Self.features) { feature in
                let isActive = feature.id == current
                Button {
                    userTookOver = true
                    withAnimation(.snappy) { current = feature.id }
                } label: {
                    Capsule()
                        .fill(.tertiary)
                        .overlay(alignment: .leading) {
                            if isActive {
                                GeometryReader { proxy in
                                    Capsule()
                                        .fill(feature.tint)
                                        .frame(width: max(proxy.size.height,
                                                          proxy.size.width * (autoAdvances ? progress : 1)))
                                }
                            }
                        }
                        .frame(width: isActive ? 28 : 8, height: 8)
                        .padding(.vertical, Theme.Spacing.sm)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
        .animation(.snappy, value: current)
        .accessibilityHidden(true)
    }

    /// Fills the active dot over one beat, then moves to the next card (wrapping to the first).
    private func advanceAfterBeat() async {
        var reset = Transaction()
        reset.disablesAnimations = true
        withTransaction(reset) { progress = 0 }
        guard autoAdvances else { return }
        // Lets the card settle (and the reset render) before the dot starts filling.
        try? await Task.sleep(for: .seconds(Self.settleSeconds))
        guard !Task.isCancelled, autoAdvances else { return }
        withAnimation(.linear(duration: Self.beatSeconds)) { progress = 1 }
        try? await Task.sleep(for: .seconds(Self.beatSeconds))
        guard !Task.isCancelled, autoAdvances else { return }
        let index = Self.features.firstIndex { $0.id == current } ?? 0
        withAnimation(.smooth(duration: 0.6)) {
            current = Self.features[(index + 1) % Self.features.count].id
        }
    }

    private struct TimerKey: Equatable {
        let current: Feature.ID?
        let autoAdvances: Bool
    }
}

/// One feature: a tinted icon tile, a bold title, a short line and a few tags, on a softly tinted card. Read by
/// VoiceOver as one element.
private struct FeatureCard: View {
    let feature: WelcomeFeatureCarousel.Feature

    @ScaledMetric(relativeTo: .title2) private var tile: CGFloat = 52

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Image(systemName: feature.icon)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: tile, height: tile)
                .background(
                    LinearGradient(colors: [feature.tint, feature.tint.opacity(0.7)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: .rect(cornerRadius: 14))
                .shadow(color: feature.tint.opacity(0.35), radius: 8, y: 4)
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(feature.title)
                    .font(.title3.weight(.bold))
                Text(feature.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            WrapLayout(spacing: Theme.Spacing.xs + 2, lineSpacing: Theme.Spacing.xs + 2) {
                ForEach(feature.tags, id: \.self) { tag in
                    Text(tag)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(feature.tint)
                        .padding(.horizontal, Theme.Spacing.sm + 2)
                        .padding(.vertical, Theme.Spacing.xs + 1)
                        .background(feature.tint.opacity(0.15), in: .capsule)
                }
            }
        }
        .padding(Theme.Spacing.lg + 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            LinearGradient(colors: [feature.tint.opacity(0.2), feature.tint.opacity(0.05)],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            in: .rect(cornerRadius: Theme.Radius.card + 4))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.Radius.card + 4)
                .strokeBorder(feature.tint.opacity(0.3), lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(feature.title). \(feature.detail)")
    }
}

#Preview {
    WelcomeFeatureCarousel()
        .padding(.vertical)
}

#Preview("AX5") {
    WelcomeFeatureCarousel()
        .dynamicTypeSize(.accessibility5)
}
