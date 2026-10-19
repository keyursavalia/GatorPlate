import SwiftUI

/// "CREATE ACCOUNT": name, email, password with a live rules checklist, the password again, the button, back to
/// sign in, legal footnote. Errors show centered under each field after the first attempt.
struct CreateAccountForm: View {
    @Bindable var viewModel: AuthViewModel
    let submit: () -> Void

    @FocusState private var focus: AuthFocusField?

    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            AuthHeader(title: "Create account", subtitle: "Post leftover food in seconds.")
                .padding(.top, Theme.Spacing.xl)

            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                nameField
                EmailField(viewModel: viewModel, focus: $focus)
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    UnderlinePasswordField(label: "Password", text: $viewModel.password,
                                           error: viewModel.passwordError, isFocused: focus == .password,
                                           isNewPassword: true)
                        .focused($focus, equals: .password)
                        .submitLabel(.next)
                    PasswordChecklist(password: viewModel.password)
                }
                UnderlinePasswordField(label: "Confirm password", text: $viewModel.confirmPassword,
                                       error: viewModel.confirmPasswordError,
                                       isFocused: focus == .confirmPassword, isNewPassword: true)
                    .focused($focus, equals: .confirmPassword)
                    .submitLabel(.join)
            }
            .onSubmit(handleReturn)

            if let formError = viewModel.formError {
                Banner(style: .error, message: formError)
            }

            VStack(spacing: Theme.Spacing.md) {
                PrimaryButton(title: "Create account", isLoading: viewModel.isSubmitting) {
                    focus = nil
                    submit()
                }
                .textCase(.uppercase)
                AuthTextButton(title: "I have an account") { viewModel.setMode(.logIn) }
            }

            LegalFootnote(lead: "By creating an account, I agree to")
        }
    }

    private var nameField: some View {
        UnderlineField(error: viewModel.nameError, isFocused: focus == .name) {
            TextField("Full name", text: $viewModel.name,
                      prompt: UnderlineField<EmptyView>.prompt("Full name", error: viewModel.nameError))
                .textContentType(.name)
                .focused($focus, equals: .name)
                .submitLabel(.next)
        }
        .onChange(of: viewModel.name) { _, newValue in
            if newValue.count > AppConfig.maxNameLength { viewModel.name = String(newValue.prefix(AppConfig.maxNameLength)) }
        }
    }

    private func handleReturn() {
        switch focus {
        case .name: focus = .email
        case .email: focus = .password
        case .password: focus = .confirmPassword
        case .confirmPassword, nil:
            focus = nil
            submit()
        }
    }
}
