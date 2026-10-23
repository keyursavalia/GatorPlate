import SwiftUI

/// First launch (and after a Terms update): a live campus map preview (`WelcomeCampusHero`) running edge to edge
/// under the status bar and fading into the page, the app tile across its bottom edge, the name and tagline, the
/// feature cards (`WelcomeFeatureCarousel`), then "Agree & continue". No account needed; accepting starts a guest
/// session. On iPad (regular width, standard text sizes) the cards are larger and centered in the space between the
/// tagline and the footer, and the footer is sized for a tablet; iPhone and accessibility sizes keep the stacked
/// layout.
struct WelcomeTermsView: View {
    let onAgree: () -> Void

    @State private var hasAppeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// The app tile's side; half of it overlaps the map.
    private static let tileSize: CGFloat = 96

    /// iPad-sized layout: regular width and a standard text size.
    private var isRegular: Bool {
        horizontalSizeClass == .regular && !dynamicTypeSize.isAccessibilitySize
    }

    var body: some View {
        // Read before the scroll view ignores the top safe area: the hero runs under the status bar and keeps its
        // notification below it.
        GeometryReader { proxy in
            let topInset = proxy.safeAreaInsets.top
            ScrollView {
                Group {
                    if isRegular {
                        // The cards sit centered between the tagline and the footer instead of leaving a gap above
                        // the footer; taller than the screen (landscape), it scrolls like the iPhone layout.
                        VStack(spacing: 0) {
                            heroAndBrand(topInset: topInset, height: proxy.size.height)
                            Spacer(minLength: Theme.Spacing.xl)
                            carousel(maxWidth: 640)
                            Spacer(minLength: Theme.Spacing.xl)
                        }
                        .frame(minHeight: proxy.size.height + topInset - Theme.Spacing.xl)
                    } else {
                        VStack(spacing: Theme.Spacing.xl) {
                            heroAndBrand(topInset: topInset, height: proxy.size.height)
                            carousel(maxWidth: 500)
                        }
                    }
                }
                .padding(.bottom, Theme.Spacing.xl)
            }
            .scrollBounceBehavior(.basedOnSize)
            .ignoresSafeArea(edges: .top)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: Theme.Spacing.lg) {
                LegalFootnote(lead: "By tapping Agree & continue, I agree to")
                // On iPad the line has room for one row; the button keeps a tablet width rather than the card's.
                PrimaryButton(title: "Agree & continue", action: onAgree)
                    .textCase(.uppercase)
                    .frame(maxWidth: isRegular ? 420 : .infinity)
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.vertical, Theme.Spacing.lg)
            .frame(maxWidth: isRegular ? 640 : 500)
            .frame(maxWidth: .infinity)
            .background(.background)
        }
        .onAppear { hasAppeared = true }
    }

    /// The campus map preview with the app tile, name and tagline across its faded bottom edge.
    private func heroAndBrand(topInset: CGFloat, height: CGFloat) -> some View {
        VStack(spacing: Theme.Spacing.md) {
            WelcomeCampusHero(topInset: topInset)
                .frame(height: topInset + height * (dynamicTypeSize.isAccessibilitySize ? 0.22 : 0.36))
            brand
                .padding(.top, -Self.tileSize / 2 - Theme.Spacing.lg)
                .padding(.horizontal, Theme.Spacing.lg)
        }
    }

    /// The feature cards, rising in after the hero.
    private func carousel(maxWidth: CGFloat) -> some View {
        WelcomeFeatureCarousel()
            .frame(maxWidth: maxWidth)
            .opacity(hasAppeared ? 1 : 0)
            .offset(y: hasAppeared || reduceMotion ? 0 : 24)
            .animation(reduceMotion ? .easeOut(duration: 0.3) : .spring(duration: 0.6).delay(0.2),
                       value: hasAppeared)
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

#Preview {
    WelcomeTermsView(onAgree: {})
}

#Preview("iPad", traits: .fixedLayout(width: 834, height: 1194)) {
    WelcomeTermsView(onAgree: {})
        .environment(\.horizontalSizeClass, .regular)
}

#Preview("AX5") {
    WelcomeTermsView(onAgree: {}).dynamicTypeSize(.accessibility5)
}
