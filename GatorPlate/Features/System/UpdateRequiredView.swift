import SwiftUI

/// Full screen shown above everything (Terms and sign-in included) when this build is older than Remote Config
/// `minimum_app_version`. No way past it; the Update button appears only when `app_store_url` is set.
struct UpdateRequiredView: View {
    let appStoreURL: URL?
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.xl) {
                AppLogoTile(size: 88, cornerRadius: 22)
                VStack(spacing: Theme.Spacing.md) {
                    Text("Update GatorPlate")
                        .font(.title.bold())
                        .accessibilityAddTraits(.isHeader)
                    Text(appStoreURL == nil
                         ? "This version can't connect anymore. Update GatorPlate from the App Store to keep using it."
                         : "This version can't connect anymore. Update from the App Store to keep using GatorPlate.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let appStoreURL {
                    PrimaryButton(title: "Update") { openURL(appStoreURL) }
                        .accessibilityHint("Opens GatorPlate in the App Store")
                }
            }
            .padding(Theme.Spacing.xl)
            .frame(maxWidth: 500)
            .frame(maxWidth: .infinity, minHeight: 0)
        }
        .scrollBounceBehavior(.basedOnSize)
        .defaultScrollAnchor(.center)
        .background(.background)
    }
}
