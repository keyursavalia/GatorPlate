import SwiftUI

/// Welcome screen features as swipeable cards (the neighbors peek in from the sides). Circular: after the last card
/// comes the first, swiping or advancing, with no rewind. Advances on its own every few seconds, with the active
/// page dot filling up as a timer, until the person swipes or taps a dot; then it stays where they put it. No
/// auto-advance with Reduce Motion or VoiceOver. Every card is the same height.
///
/// The loop: the strip is the cards with copies of the last two in front and the first two behind
/// (`4' 5' 1 2 3 4 5 1' 2'`). Scrolling onto a copy and settling there jumps, without animation, to the real card
/// it copies, which looks the same with the same neighbors, so the strip never runs out. Nine light views, no
/// timers beyond one sleep per card.
struct WelcomeFeatureCarousel: View {
    struct Feature: Identifiable {
        let id: Int
        let icon: String
        let title: String
        let detail: String
        let points: [String]
        let tint: Color
    }

    static let features = [
        Feature(id: 0, icon: "map.fill", title: "Live campus map",
                detail: "See free food on campus right now. No account needed.",
                points: ["Live", "No sign-up"], tint: Theme.Palette.success),
        Feature(id: 1, icon: "camera.viewfinder", title: "Snap it, AI drafts it",
                detail: "Gemini fills in the food, diet and allergens from a photo. You check it before it posts.",
                points: ["Food", "Diet", "Allergens"], tint: Theme.Palette.accent),
        Feature(id: 2, icon: "bell.badge.fill", title: "Alerts you choose",
                detail: "Get notified only for the food and places you care about.",
                points: ["Diet", "Places", "Quiet hours"], tint: Theme.Palette.brandPurple),
        Feature(id: 3, icon: "exclamationmark.shield.fill", title: "Eat smart",
                detail: "Eat at your own risk and ask about allergens. Report or block anything that's off.",
                points: ["Report", "Block", "Posts end within an hour"], tint: Theme.Palette.warning),
        Feature(id: 4, icon: "lock.shield.fill", title: "Private by design",
                detail: "Your location stays on your phone. Your data is never sold.",
                points: ["No ads", "No tracking"], tint: Theme.Palette.brandGold),
    ]

    /// One position in the strip: a real card, or a copy at either end.
    private struct Slot: Identifiable {
        let id: Int
        let feature: Int
        let isCopy: Bool
    }

    /// Copies on each side; two keep both neighbors right while the strip sits on a copy.
    private static let copies = 2
    private static let slots: [Slot] = {
        let count = features.count
        return (0..<(count + 2 * copies)).map { position in
            let feature = ((position - copies) % count + count) % count
            let isCopy = position < copies || position >= copies + count
            return Slot(id: position, feature: feature, isCopy: isCopy)
        }
    }()

    /// The slot that shows `feature` in the real run.
    private static func realSlot(_ feature: Int) -> Int { feature + copies }

    /// Seconds each card shows before the next.
    private static let beatSeconds = 4.5
    /// Lets a card settle before its dot starts filling.
    private static let settleSeconds = 0.4

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @State private var position: Int? = Self.realSlot(0)
    /// Set once the person swipes or taps a dot: from then on the carousel doesn't move by itself.
    @State private var userTookOver = false
    /// The active dot's timer fill, 0...1.
    @State private var progress: CGFloat = 0

    private var autoAdvances: Bool { !reduceMotion && !voiceOverEnabled && !userTookOver }
    private var currentFeature: Int { Self.slots[position ?? Self.realSlot(0)].feature }

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            ScrollView(.horizontal) {
                HStack(spacing: Theme.Spacing.md) {
                    ForEach(Self.slots) { slot in
                        FeatureCard(feature: Self.features[slot.feature])
                            .containerRelativeFrame(.horizontal)
                            .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                                content.opacity(phase.isIdentity ? 1 : 0.5)
                            }
                            // VoiceOver reads each feature once.
                            .accessibilityHidden(slot.isCopy)
                    }
                }
                // Every card as tall as the tallest.
                .fixedSize(horizontal: false, vertical: true)
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, Theme.Spacing.xl, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $position)
            .scrollIndicators(.hidden)
            .onScrollPhaseChange { _, phase in
                if phase == .interacting { userTookOver = true }
                if phase == .idle { leaveCopy() }
            }
            pageDots
        }
        // Keyed on the feature, not the slot, so leaving a copy doesn't restart the timer.
        .task(id: TimerKey(feature: currentFeature, autoAdvances: autoAdvances)) { await advanceAfterBeat() }
    }

    /// One dot per card; the active one is a capsule that fills as its timer runs. Tapping a dot shows that card.
    /// Hidden from VoiceOver, which reaches every card by swiping.
    private var pageDots: some View {
        HStack(spacing: Theme.Spacing.sm) {
            ForEach(Self.features) { feature in
                let isActive = feature.id == currentFeature
                Button {
                    userTookOver = true
                    withAnimation(.snappy) { position = Self.realSlot(feature.id) }
                } label: {
                    Capsule()
                        .fill(.quaternary)
                        .overlay(alignment: .leading) {
                            if isActive {
                                GeometryReader { proxy in
                                    Capsule()
                                        .fill(.primary)
                                        .frame(width: max(proxy.size.height,
                                                          proxy.size.width * (autoAdvances ? progress : 1)))
                                }
                            }
                        }
                        .frame(width: isActive ? 24 : 7, height: 7)
                        .padding(.vertical, Theme.Spacing.sm)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
        .animation(.snappy, value: currentFeature)
        .accessibilityHidden(true)
    }

    /// On a copy, jumps without animation to the real card it copies (same card, same neighbors, so it's unseen).
    /// Returns whether it jumped.
    @discardableResult
    private func leaveCopy() -> Bool {
        guard let position, Self.slots[position].isCopy else { return false }
        var jump = Transaction()
        jump.disablesAnimations = true
        withTransaction(jump) { self.position = Self.realSlot(Self.slots[position].feature) }
        return true
    }

    /// Fills the active dot over one beat, then scrolls forward one card (onto the first card's copy after the last).
    private func advanceAfterBeat() async {
        var reset = Transaction()
        reset.disablesAnimations = true
        withTransaction(reset) { progress = 0 }
        guard autoAdvances else { return }
        try? await Task.sleep(for: .seconds(Self.settleSeconds))
        guard !Task.isCancelled, autoAdvances else { return }
        withAnimation(.linear(duration: Self.beatSeconds)) { progress = 1 }
        try? await Task.sleep(for: .seconds(Self.beatSeconds))
        guard !Task.isCancelled, autoAdvances else { return }
        // Normally done when the last scroll went idle; repeated here so forward always has room. The jump gets its
        // own frame, or it would merge with the animated scroll below into one long scroll backwards.
        if leaveCopy() {
            try? await Task.sleep(for: .milliseconds(50))
            guard !Task.isCancelled, autoAdvances else { return }
        }
        let next = (position ?? Self.realSlot(0)) + 1
        withAnimation(.smooth(duration: 0.6)) { position = next }
    }

    private struct TimerKey: Equatable {
        let feature: Int
        let autoAdvances: Bool
    }
}

/// One feature on a plain card: an icon tile beside the title, a short line, then a divider and a few checkmarked
/// points. Read by VoiceOver as one element.
private struct FeatureCard: View {
    let feature: WelcomeFeatureCarousel.Feature

    @ScaledMetric(relativeTo: .headline) private var tile: CGFloat = 36

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: feature.icon)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(feature.tint)
                    .frame(width: tile, height: tile)
                    .background(feature.tint.opacity(0.15), in: .rect(cornerRadius: 9))
                Text(feature.title)
                    .font(.headline)
            }
            Text(feature.detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Divider()
            WrapLayout(spacing: Theme.Spacing.lg, lineSpacing: Theme.Spacing.xs) {
                ForEach(feature.points, id: \.self) { point in
                    Label {
                        Text(point)
                    } icon: {
                        Image(systemName: "checkmark")
                            .foregroundStyle(feature.tint)
                    }
                    .labelStyle(PointLabelStyle())
                }
            }
            .font(.footnote.weight(.medium))
            .foregroundStyle(.secondary)
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.background.secondary, in: .rect(cornerRadius: Theme.Radius.card))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(feature.title). \(feature.detail)")
    }
}

/// A checkmark tight against its text.
private struct PointLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: Theme.Spacing.xs) {
            configuration.icon.imageScale(.small)
            configuration.title
        }
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
