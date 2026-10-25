import SwiftUI

/// Remote Config notices for the top of Map and Feed: the service notice and the "new version" banner. Updates live
/// when the owner publishes (the runtime config is observable).
struct RuntimeNotices: View {
    /// Glass over the map, tinted cards in the Feed.
    var isGlass = false

    @Environment(\.appEnvironment) private var environment
    @Environment(\.openURL) private var openURL
    /// Bumped on dismiss so the banner hides at once (UserDefaults isn't observed).
    @State private var dismissals = 0

    var body: some View {
        let config = environment.runtime.current
        if !config.serviceNotice.isEmpty {
            ServiceNoticeBanner(message: config.serviceNotice, level: config.serviceNoticeLevel, isGlass: isGlass)
        }
        if let version = recommendedVersion(config) {
            updateBanner(version: version, url: config.appStoreURL)
        }
    }

    private func recommendedVersion(_ config: RuntimeConfig) -> AppVersion? {
        _ = dismissals
        guard let version = config.recommendedAppVersion,
              UpdateGate.isRecommended(current: AppVersion.current, recommended: version),
              !UserDefaults.standard.bool(forKey: UpdateGate.dismissalKey(version)) else { return nil }
        return version
    }

    private func updateBanner(version: AppVersion, url: URL?) -> some View {
        var actions: [Banner.Action] = []
        if let url { actions.append(Banner.Action(title: "Update") { openURL(url) }) }
        actions.append(Banner.Action(title: "Not now", isPrimary: false) {
            UserDefaults.standard.set(true, forKey: UpdateGate.dismissalKey(version))
            dismissals += 1
        })
        return Banner(style: .info, message: "A new version of GatorPlate is available.", actions: actions)
            .background {
                if isGlass { Color.clear.glassEffect(.regular, in: .rect(cornerRadius: Theme.Radius.photo)) }
            }
    }
}
