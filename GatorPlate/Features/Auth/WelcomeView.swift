import SwiftUI

/// Screen 1: log in / sign up. Reads the `AuthViewModel` from the environment.
struct WelcomeView: View {
    @Environment(AuthViewModel.self) private var viewModel
    @FocusState private var focus: AuthField?
    @State private var showTerms = false

    var body: some View {
        @Bindable var viewModel = viewModel

        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                header

                AuthTextField(
                    title: "SFSU email",
                    text: $viewModel.email,
                    kind: .email,
                    error: viewModel.fieldErrors[.email]
                )
                .focused($focus, equals: .email)
                .submitLabel(.next)
                .onSubmit { advance(from: .email) }

                AuthTextField(
                    title: "Password",
                    text: $viewModel.password,
                    kind: .password,
                    error: viewModel.fieldErrors[.password]
                )
                .focused($focus, equals: .password)
                .submitLabel(viewModel.mode == .signUp ? .next : .go)
                .onSubmit { advance(from: .password) }

                if viewModel.mode == .signUp {
                    SignUpFields(viewModel: viewModel, focus: $focus, onSubmit: submit)
                }

                if let message = viewModel.submitError {
                    Banner(kind: .error, message: message)
                }

                PrimaryButton(
                    title: viewModel.mode == .signUp ? "Create account" : "Log in",
                    isLoading: viewModel.isSubmitting,
                    action: submit
                )

                modeToggle
                footer
            }
            .padding(Theme.Spacing.l)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.surface)
        .sheet(isPresented: $showTerms) {
            TermsOfUseSheet(requiresAcceptance: false)
        }
        .onChange(of: viewModel.validationFailureCount) {
            guard let field = viewModel.firstInvalidField else { return }
            focus = field
            if let message = viewModel.fieldErrors[field] {
                AccessibilityNotification.Announcement(message).post()
            }
        }
        .onChange(of: viewModel.submitError) { _, message in
            if let message { AccessibilityNotification.Announcement(message).post() }
        }
    }

    private var header: some View {
        VStack(spacing: Theme.Spacing.s) {
            Image(systemName: "fork.knife.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color.brandPurple)
                .accessibilityHidden(true)
            Text(AppConfig.appName)
                .font(.largeTitle.bold())
                .accessibilityAddTraits(.isHeader)
            Text("Free food, found fast.")
                .font(.title2)
                .foregroundStyle(.secondary)
            if !AppConfig.requireEmailVerification {
                Text("DEMO MODE")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.l)
        .accessibilityElement(children: .combine)
    }

    private var modeToggle: some View {
        Button {
            focus = nil
            viewModel.mode = viewModel.mode == .signUp ? .logIn : .signUp
        } label: {
            Text(viewModel.mode == .signUp ? "Have an account? Log in" : "New here? Create an account")
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: Theme.minTapTarget)
        }
        .tint(Color.brandPurple)
    }

    private var footer: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Text("By continuing you agree to the Terms of Use.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Button("Read the Terms of Use") { showTerms = true }
                .font(.footnote.weight(.semibold))
                .frame(minHeight: Theme.minTapTarget)
                .tint(Color.brandPurple)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }

    private func advance(from field: AuthField) {
        switch field {
        case .email:
            focus = .password
        case .password:
            if viewModel.mode == .signUp {
                focus = viewModel.accountType == .student ? .name : .orgName
            } else {
                submit()
            }
        case .name, .orgName:
            submit()
        }
    }

    private func submit() {
        focus = nil
        Task { await viewModel.submit() }
    }
}

#Preview("Log in") {
    WelcomeView()
        .environment(AuthViewModel(auth: MockAuthService(), initialState: .signedOut))
        .environment(\.appEnvironment, .mock)
}

#Preview("Sign up, AX3 dark") {
    let viewModel = AuthViewModel(auth: MockAuthService(), initialState: .signedOut)
    viewModel.mode = .signUp
    return WelcomeView()
        .environment(viewModel)
        .environment(\.appEnvironment, .mock)
        .dynamicTypeSize(.accessibility3)
        .preferredColorScheme(.dark)
}
