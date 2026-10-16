import SwiftUI

/// "SIGN IN": email, password with an eye toggle, forgot password, the button, create account, legal footnote.
struct SignInForm: View {
    @Bindable var viewModel: AuthViewModel
    let subtitle: String
    let submit: () -> Void

    @FocusState private var focus: AuthFocusField?
    @State private var showsPasswordReset = false

    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            AuthHeader(title: "Sign in", subtitle: subtitle)
                .padding(.top, Theme.Spacing.xl)

            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                EmailField(viewModel: viewModel, focus: $focus)
                UnderlinePasswordField(label: "Password", text: $viewModel.password, error: viewModel.passwordError,
                                       isFocused: focus == .password)
                    .focused($focus, equals: .password)
                    .submitLabel(.go)
                AuthTextButton(title: "Forgot password") { showsPasswordReset = true }
            }
            .onSubmit(handleReturn)

            if let formError = viewModel.formError {
                Banner(style: .error, message: formError)
            }

            VStack(spacing: Theme.Spacing.md) {
                PrimaryButton(title: "Sign in", isLoading: viewModel.isSubmitting) {
                    focus = nil
                    submit()
                }
                .textCase(.uppercase)
                AuthTextButton(title: "Create account") { viewModel.setMode(.signUp) }
            }

            LegalFootnote(lead: "By signing in, I agree to")
        }
        .sheet(isPresented: $showsPasswordReset) {
            ForgotPasswordSheet(viewModel: viewModel)
        }
    }

    private func handleReturn() {
        switch focus {
        case .name, .email: focus = .password
        case .password, nil:
            focus = nil
            submit()
        }
    }
}

/// Email on an underline, shared by sign-in and create account.
struct EmailField: View {
    @Bindable var viewModel: AuthViewModel
    var focus: FocusState<AuthFocusField?>.Binding

    var body: some View {
        UnderlineField(error: viewModel.emailError, isFocused: focus.wrappedValue == .email) {
            TextField("Email address", text: $viewModel.email,
                      prompt: UnderlineField<EmptyView>.prompt("Email address", error: viewModel.emailError))
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused(focus, equals: .email)
                .submitLabel(.next)
        }
        .onChange(of: viewModel.email) { _, newValue in
            if newValue.count > AppConfig.maxEmailLength {
                viewModel.email = String(newValue.prefix(AppConfig.maxEmailLength))
            }
        }
    }
}
