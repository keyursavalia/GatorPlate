import SwiftUI

/// Sprint 0 placeholder root screen.
struct RootView: View {
    @Environment(\.appEnvironment) private var environment

    var body: some View {
        VStack(spacing: Theme.Spacing.l) {
            Image(systemName: "fork.knife.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color.brandPurple)
                .accessibilityHidden(true)

            Text(AppConfig.appName)
                .font(.largeTitle.bold())

            Label(
                environment.isFirebaseConfigured ? "Firebase connected" : "Firebase not configured",
                systemImage: environment.isFirebaseConfigured ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
            )
            .font(.headline)
            .foregroundStyle(environment.isFirebaseConfigured ? Color.success : Color.warning)

            Text("DEMO MODE")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .padding(Theme.Spacing.l)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.surface)
        .accessibilityElement(children: .combine)
    }
}

#Preview("Connected") {
    var environment = AppEnvironment.mock
    environment.isFirebaseConfigured = true
    return RootView().environment(\.appEnvironment, environment)
}

#Preview("Not configured") {
    RootView().environment(\.appEnvironment, .mock)
}
