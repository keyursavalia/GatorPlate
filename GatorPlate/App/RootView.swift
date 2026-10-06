import SwiftUI

/// Switches on `AuthState`.
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
            case .signedOut:
                WelcomeView(viewModel: viewModel)
            case .needsVerification(let profile):
                VerifyEmailView(viewModel: viewModel, profile: profile)
            case .needsTerms:
                TermsOfUseSheet(requiresAcceptance: true, isSubmitting: viewModel.isSubmitting,
                                errorMessage: viewModel.formError,
                                onAccept: { Task { await viewModel.acceptTerms() } },
                                onDismiss: { viewModel.signOut() })
            case .signedIn(let profile):
                MainTabView(profile: profile, onSignOut: { viewModel.signOut() })
            case .error(let message):
                AuthErrorView(message: message,
                              onRetry: { Task { await viewModel.retry() } },
                              onSignOut: { viewModel.signOut() })
            }
        }
        .task { viewModel.start() }
    }
}

#Preview("Signed out") {
    RootView(viewModel: AuthViewModel(auth: MockAuthService()))
}
