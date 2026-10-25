import SwiftUI

/// The app logo (the gator on purple, the same art as the home-screen icon) as a rounded tile. Fixed size like an app
/// icon. Decorative to VoiceOver: callers always place it next to the app name.
struct AppLogoTile: View {
    let size: CGFloat
    let cornerRadius: CGFloat

    var body: some View {
        Image(.appLogo)
            .resizable()
            .interpolation(.high)
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(.rect(cornerRadius: cornerRadius))
            .accessibilityHidden(true)
    }
}
