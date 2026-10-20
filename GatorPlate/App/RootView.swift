import SwiftUI

/// Switches on `AuthState`: Terms gate on first launch, then the app for guests and accounts alike.
struct RootView: View {
    @Bindable var viewModel: AuthViewModel
    @Environment(\.appEnvironment) private var environment

    var body: some View {
        // Remote Config `minimum_app_version`: covers everything, Terms and sign-in included. Live, so a publish
        // applies without a relaunch; an unreadable version on either side never gates.
        let config = environment.runtime.current
        if UpdateGate.isRequired(current: AppVersion.current, minimum: config.minimumAppVersion) {
            UpdateRequiredView(appStoreURL: config.appStoreURL)
        } else {
            content
        }
    }

    private var content: some View {
        Group {
            switch viewModel.state {
            case .loading:
                ProgressView()
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityLabel("Loading")
            case .needsTerms:
                WelcomeTermsView { viewModel.acceptTermsGate() }
            case .ready(let session):
                MainTabView(authSession: session, auth: viewModel)
            case .error(let message):
                AuthErrorView(message: message,
                              onRetry: { Task { await viewModel.retry() } },
                              onSignOut: { viewModel.startOver() })
            }
        }
        .task { viewModel.start() }
    }
}

#Preview("First launch") {
    RootView(viewModel: AuthViewModel(auth: MockAuthService(), account: MockAccountService(),
                                      terms: TermsAcceptance(defaults: UserDefaults(suiteName: "preview") ?? .standard)))
}
