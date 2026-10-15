import SwiftUI

/// Screen 1: log in or sign up.
struct WelcomeView: View {
    @Bindable var viewModel: AuthViewModel
    @FocusState private var focus: AuthFocusField?
    @State private var showsTerms = false
    @State private var showsPasswordReset = false

    private var isSignUp: Bool { viewModel.mode == .signUp }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.xl) {
                header
                if viewModel.showsAccountDeleted {
                    Banner(style: .info, message: AccountMessages.deleted)
                }
                fields
                if !isSignUp {
                    Button("Forgot password?") { showsPasswordReset = true }
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, minHeight: Theme.Size.minTapTarget, alignment: .trailing)
                }
                if let formError = viewModel.formError {
                    Banner(style: .error, message: formError)
                }
                PrimaryButton(title: "Continue", isLoading: viewModel.isSubmitting) {
                    focus = nil
                    Task { await viewModel.submit() }
                }
                footer
            }
            .padding(Theme.Spacing.xl)
            .frame(maxWidth: 500)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .sheet(isPresented: $showsTerms) {
            TermsOfUseSheet(onDismiss: { showsTerms = false })
        }
        .sheet(isPresented: $showsPasswordReset) {
            ForgotPasswordSheet(viewModel: viewModel)
        }
    }

    private var header: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "fork.knife.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(Theme.Palette.brandPurple)
                .accessibilityHidden(true)
            Text(AppConfig.appName)
                .font(.largeTitle.bold())
                .accessibilityAddTraits(.isHeader)
            Text("Free food, found fast.")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .padding(.top, Theme.Spacing.xl)
    }

    private var fields: some View {
        VStack(spacing: Theme.Spacing.lg) {
            if isSignUp {
                SignUpFields(viewModel: viewModel, focus: $focus)
            }
            AuthTextField(label: "Email", error: viewModel.emailError) {
                TextField("Email", text: $viewModel.email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focus, equals: .email)
                    .submitLabel(.next)
            }
            .onChange(of: viewModel.email) { _, newValue in
                if newValue.count > AppConfig.maxEmailLength {
                    viewModel.email = String(newValue.prefix(AppConfig.maxEmailLength))
                }
            }
            AuthTextField(label: "Password", error: viewModel.passwordError) {
                SecureField("Password", text: $viewModel.password)
                    .textContentType(isSignUp ? .newPassword : .password)
                    .focused($focus, equals: .password)
                    .submitLabel(isSignUp ? .join : .go)
            }
        }
        .onSubmit(handleReturn)
    }

    private var footer: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Button(isSignUp ? "Have an account? Log in" : "New here? Sign up") {
                viewModel.toggleMode()
            }
            .font(.body)
            .frame(minHeight: Theme.Size.minTapTarget)

            Text("By continuing you agree to the")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Button("Terms of Use") { showsTerms = true }
                .font(.footnote)
                .frame(minHeight: Theme.Size.minTapTarget)
        }
        .multilineTextAlignment(.center)
    }

    private func handleReturn() {
        switch focus {
        case .name: focus = .email
        case .email: focus = .password
        case .password, nil:
            focus = nil
            Task { await viewModel.submit() }
        }
    }
}

#Preview("Log in") {
    WelcomeView(viewModel: AuthViewModel(auth: MockAuthService(), account: MockAccountService()))
}

#Preview("Sign up, AX5") {
    let viewModel = AuthViewModel(auth: MockAuthService(), account: MockAccountService())
    viewModel.mode = .signUp
    return WelcomeView(viewModel: viewModel).dynamicTypeSize(.accessibility5)
}
