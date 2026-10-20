import SwiftUI

/// First launch (and after a Terms update): a live campus map preview (`WelcomeCampusHero`) with the app tile across
/// its bottom edge, the name and tagline, three short feature rows, then "Agree & continue". No account needed;
/// accepting starts a guest session.
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
                detail: "See free food right now. No account needed.", tint: Theme.Palette.success),
        Feature(id: "alerts", icon: "bell.badge.fill", title: "Alerts you choose",
                detail: "Get notified only for the food you care about.", tint: Theme.Palette.brandPurple),
        Feature(id: "safety", icon: "exclamationmark.shield.fill", title: "Eat smart",
                detail: "Eat at your own risk; ask about allergens.",
                tint: Theme.Palette.warning),
    ]

    @State private var hasAppeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// The app tile's side; half of it overlaps the map.
    private static let tileSize: CGFloat = 96

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.xl) {
                VStack(spacing: Theme.Spacing.md) {
                    WelcomeCampusHero()
                        .containerRelativeFrame(.vertical) { height, _ in
                            height * (dynamicTypeSize.isAccessibilitySize ? 0.2 : 0.33)
                        }
                    brand
                        .padding(.top, -Self.tileSize / 2 - Theme.Spacing.lg)
                }
                .padding(.top, Theme.Spacing.sm)
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    ForEach(Array(features.enumerated()), id: \.element.id) { index, feature in
                        FeatureRow(icon: feature.icon, title: feature.title, detail: feature.detail,
                                   tint: feature.tint)
                            .opacity(hasAppeared ? 1 : 0)
                            .offset(y: hasAppeared || reduceMotion ? 0 : 16)
                            .animation(reduceMotion ? .easeOut(duration: 0.3)
                                                    : .spring(duration: 0.5).delay(0.12 * Double(index + 1)),
                                       value: hasAppeared)
                    }
                }
                .padding(.horizontal, Theme.Spacing.sm)
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.xl)
            .frame(maxWidth: 500)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: Theme.Spacing.lg) {
                LegalFootnote(lead: "By tapping Agree & continue, I agree to",
                              trailing: "including AI processing of food photos and safety reports by Google's Gemini")
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

    /// App mark on a brand gradient tile (across the map's faded edge), the name and the tagline.
    private var brand: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: "fork.knife")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: Self.tileSize, height: Self.tileSize)
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

/// One welcome point: a tinted icon tile, a bold title and a short line, with no card behind it so the page stays
/// light. Stacks the icon above the text at accessibility sizes. Read by VoiceOver as one element.
private struct FeatureRow: View {
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    WelcomeTermsView(onAgree: {})
}

#Preview("AX5") {
    WelcomeTermsView(onAgree: {}).dynamicTypeSize(.accessibility5)
}
