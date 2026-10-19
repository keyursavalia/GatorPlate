import SwiftUI

/// First launch (and after a Terms update): what GatorPlate is, as three short feature cards, then "Agree &
/// continue". No account needed; accepting starts a guest session.
struct WelcomeTermsView: View {
    let onAgree: () -> Void

    private struct Feature: Identifiable {
        let id: String
        let icon: String
        let title: String
        let detail: String
        let tint: Color
    }

    private let features = [
        Feature(id: "browse", icon: "map.fill", title: "Live campus map",
                detail: "See free food right now. No account needed.", tint: Theme.Palette.brandPurple),
        Feature(id: "alerts", icon: "bell.badge.fill", title: "Alerts you choose",
                detail: "Get notified only for the food you care about.", tint: Theme.Palette.brandPurple),
        Feature(id: "safety", icon: "exclamationmark.shield.fill", title: "Eat smart",
                detail: "Food is shared by students. Eat at your own risk and confirm allergens with the host.",
                tint: Theme.Palette.warning),
    ]

    @State private var hasAppeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.xxl) {
                hero
                    .padding(.top, Theme.Spacing.xxl)
                VStack(spacing: Theme.Spacing.md) {
                    ForEach(Array(features.enumerated()), id: \.element.id) { index, feature in
                        FeatureCard(icon: feature.icon, title: feature.title, detail: feature.detail,
                                    tint: feature.tint)
                            .opacity(hasAppeared ? 1 : 0)
                            .offset(y: hasAppeared || reduceMotion ? 0 : 16)
                            .animation(reduceMotion ? .easeOut(duration: 0.3)
                                                    : .spring(duration: 0.5).delay(0.12 * Double(index + 1)),
                                       value: hasAppeared)
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.bottom, Theme.Spacing.xl)
            .frame(maxWidth: 500)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: Theme.Spacing.lg) {
                LegalFootnote(lead: "By tapping Agree & continue, I agree to")
                PrimaryButton(title: "Agree & continue", action: onAgree)
                    .textCase(.uppercase)
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.vertical, Theme.Spacing.lg)
            .frame(maxWidth: 500)
            .frame(maxWidth: .infinity)
            .background(.background)
        }
        .onAppear { hasAppeared = true }
    }

    /// App mark on a brand gradient tile, the name and the tagline.
    private var hero: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: "fork.knife")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 96, height: 96)
                .background(
                    LinearGradient(colors: [Theme.Palette.brandPurple, Theme.Palette.brandPurple.opacity(0.7)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: .rect(cornerRadius: 24))
                .shadow(color: Theme.Palette.brandPurple.opacity(0.35), radius: 16, y: 8)
                .accessibilityHidden(true)
            AuthHeader(title: AppConfig.appName, subtitle: "Free food on campus, found fast.")
        }
    }
}

/// One welcome point: a tinted icon tile, a bold title and a short line. Stacks the icon above the text at
/// accessibility sizes. Read by VoiceOver as one element.
private struct FeatureCard: View {
    let icon: String
    let title: String
    let detail: String
    let tint: Color

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .title3) private var tile: CGFloat = 44

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Theme.Spacing.md))
            : AnyLayout(HStackLayout(alignment: .top, spacing: Theme.Spacing.lg))
        layout {
            Image(systemName: icon)
                .font(.title3.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: tile, height: tile)
                .background(tint.opacity(0.15), in: .rect(cornerRadius: 12))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: .rect(cornerRadius: Theme.Radius.card))
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    WelcomeTermsView(onAgree: {})
}

#Preview("AX5") {
    WelcomeTermsView(onAgree: {}).dynamicTypeSize(.accessibility5)
}
