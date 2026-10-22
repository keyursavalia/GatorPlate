import SwiftUI

/// First launch (and after a Terms update): a live campus map preview (`WelcomeCampusHero`) running edge to edge
/// under the status bar and fading into the page, the app tile across its bottom edge, the name and tagline, the
/// feature cards (`WelcomeFeatureCarousel`), then "Agree & continue". No account needed; accepting starts a guest
/// session.
struct WelcomeTermsView: View {
    let onAgree: () -> Void

    @State private var hasAppeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// The app tile's side; half of it overlaps the map.
    private static let tileSize: CGFloat = 96

    var body: some View {
        // Read before the scroll view ignores the top safe area: the hero runs under the status bar and keeps its
        // notification below it.
        GeometryReader { proxy in
            let topInset = proxy.safeAreaInsets.top
            ScrollView {
                VStack(spacing: Theme.Spacing.xl) {
                    VStack(spacing: Theme.Spacing.md) {
                        WelcomeCampusHero(topInset: topInset)
                            .frame(height: topInset + proxy.size.height
                                * (dynamicTypeSize.isAccessibilitySize ? 0.22 : 0.36))
                        brand
                            .padding(.top, -Self.tileSize / 2 - Theme.Spacing.lg)
                            .padding(.horizontal, Theme.Spacing.lg)
                    }
                    WelcomeFeatureCarousel()
                        .frame(maxWidth: 500)
                        .opacity(hasAppeared ? 1 : 0)
                        .offset(y: hasAppeared || reduceMotion ? 0 : 24)
                        .animation(reduceMotion ? .easeOut(duration: 0.3) : .spring(duration: 0.6).delay(0.2),
                                   value: hasAppeared)
                }
                .padding(.bottom, Theme.Spacing.xl)
            }
            .scrollBounceBehavior(.basedOnSize)
            .ignoresSafeArea(edges: .top)
        }
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

#Preview("AX5") {
    WelcomeTermsView(onAgree: {}).dynamicTypeSize(.accessibility5)
}
