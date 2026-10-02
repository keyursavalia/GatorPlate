import SwiftUI

/// Root of the app. Owns the `AuthViewModel` and switches screens on its session state.
struct AuthGate: View {
    @State private var viewModel: AuthViewModel
    @Environment(\.appEnvironment) private var environment

    init(auth: any AuthService) {
        _viewModel = State(initialValue: AuthViewModel(auth: auth))
    }

    var body: some View {
        content
            .task(id: viewModel.sessionAttempt) { await viewModel.start() }
            .sheet(isPresented: needsTerms) {
                TermsOfUseSheet(requiresAcceptance: true)
                    .interactiveDismissDisabled()
            }
            // Must come after `.sheet`: a sheet only inherits the environment of modifiers applied outside it.
            .environment(viewModel)
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            LaunchView()
        case .signedOut, .needsTerms:
            WelcomeView()
        case .signedIn(let profile):
            MainTabView(profile: profile, environment: environment)
        case .error(let message):
            EmptyState(
                systemImage: "wifi.exclamationmark",
                title: "Can't load your account",
                message: message,
                actionTitle: "Try again"
            ) { viewModel.retry() }
            .frame(maxHeight: .infinity)
            .background(Color.surface)
        }
    }

    /// Terms can only be dismissed by accepting or declining, never by swiping away.
    private var needsTerms: Binding<Bool> {
        Binding(
            get: {
                if case .needsTerms = viewModel.state { return true }
                return false
            },
            set: { _ in }
        )
    }
}

/// Shown while the persisted session is checked.
struct LaunchView: View {
    var body: some View {
        VStack(spacing: Theme.Spacing.l) {
            Image(systemName: "fork.knife.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color.brandPurple)
                .accessibilityHidden(true)
            Text(AppConfig.appName)
                .font(.largeTitle.bold())
            ProgressView()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.surface)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(AppConfig.appName), loading")
    }
}

#Preview("Launch") {
    LaunchView().environment(\.appEnvironment, .mock)
}

#Preview("Signed out flow") {
    AuthGate(auth: MockAuthService())
        .environment(\.appEnvironment, .mock)
}
