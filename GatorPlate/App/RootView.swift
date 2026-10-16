import SwiftUI

/// Switches on `AuthState`: Terms gate on first launch, then the app for guests and accounts alike.
struct RootView: View {
    @Bindable var viewModel: AuthViewModel

    var body: some View {
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
