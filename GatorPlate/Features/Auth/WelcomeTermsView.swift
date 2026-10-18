import SwiftUI

/// First launch (and after a Terms update): what GatorPlate is, then "Agree & continue". No account needed;
/// accepting starts a guest session.
struct WelcomeTermsView: View {
    let onAgree: () -> Void

    private struct Point: Identifiable {
        let id: String
        let icon: String
        let text: String
    }

    private let points = [
        Point(id: "browse", icon: "map", text: "See free food on campus right now. No account needed."),
        Point(id: "alerts", icon: "bell.badge", text: "Get notifications for the food you care about."),
        Point(id: "risk", icon: "exclamationmark.shield",
              text: "Food is shared by students. Eat at your own risk and confirm allergens with the host."),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.xxl) {
                VStack(spacing: Theme.Spacing.lg) {
                    Image(systemName: "fork.knife.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(Theme.Palette.brandPurple)
                        .accessibilityHidden(true)
                    AuthHeader(title: AppConfig.appName, subtitle: "Free food on campus, found fast.")
                }
                .padding(.top, Theme.Spacing.xxl)

                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    ForEach(points) { point in
                        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.md) {
                            Image(systemName: point.icon)
                                .foregroundStyle(Theme.Palette.brandPurple)
                                .frame(minWidth: 28)
                                .accessibilityHidden(true)
                            Text(point.text).font(.body)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .frame(maxWidth: 500)
            .frame(maxWidth: .infinity)
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
    }
}

#Preview {
    WelcomeTermsView(onAgree: {})
}

#Preview("AX5") {
    WelcomeTermsView(onAgree: {}).dynamicTypeSize(.accessibility5)
}
