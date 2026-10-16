import SwiftUI

/// "CREATE ACCOUNT": account type as radio rows, the matching name, email, password with its rule, the button,
/// back to sign in, legal footnote. Errors show centered under each field after the first attempt.
struct CreateAccountForm: View {
    @Bindable var viewModel: AuthViewModel
    let submit: () -> Void

    @FocusState private var focus: AuthFocusField?

    private var isOrganization: Bool { viewModel.accountType == .organization }

    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            AuthHeader(title: "Create account", subtitle: "Post leftover food for your org in seconds.")
                .padding(.top, Theme.Spacing.xl)

            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                accountTypePicker
                nameField
                EmailField(viewModel: viewModel, focus: $focus)
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    UnderlinePasswordField(label: "Password", text: $viewModel.password,
                                           error: viewModel.passwordError, isFocused: focus == .password,
                                           isNewPassword: true)
                        .focused($focus, equals: .password)
                        .submitLabel(.join)
                    Text("\(AppConfig.minPasswordLength)+ characters")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
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

    private var accountTypePicker: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("I'm posting as")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            ForEach([AccountType.student, .organization], id: \.self) { type in
                let isSelected = viewModel.accountType == type
                Button {
                    viewModel.accountType = type
                } label: {
                    HStack(spacing: Theme.Spacing.md) {
                        Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                            .font(.title2)
                            .foregroundStyle(isSelected ? Theme.Palette.brandPurple : Color.secondary)
                            .accessibilityHidden(true)
                        Text(type == .student ? "A student" : "A student organization")
                            .font(.body.weight(isSelected ? .semibold : .regular))
                            .foregroundStyle(.primary)
                        Spacer(minLength: 0)
                    }
                    .frame(minHeight: Theme.Size.minTapTarget)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(type == .student ? "Student" : "Student organization")
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Account type")
    }

    private var nameField: some View {
        let label = isOrganization ? "Organization name" : "Full name"
        return UnderlineField(error: viewModel.nameError, isFocused: focus == .name) {
            TextField(label, text: isOrganization ? $viewModel.orgName : $viewModel.name,
                      prompt: UnderlineField<EmptyView>.prompt(label, error: viewModel.nameError))
                .textContentType(isOrganization ? .organizationName : .name)
                .focused($focus, equals: .name)
                .submitLabel(.next)
        }
        .onChange(of: viewModel.name) { _, newValue in
            if newValue.count > AppConfig.maxNameLength { viewModel.name = String(newValue.prefix(AppConfig.maxNameLength)) }
        }
        .onChange(of: viewModel.orgName) { _, newValue in
            if newValue.count > AppConfig.maxNameLength {
                viewModel.orgName = String(newValue.prefix(AppConfig.maxNameLength))
            }
        }
    }

    private func handleReturn() {
        switch focus {
        case .name: focus = .email
        case .email: focus = .password
        case .password, nil:
            focus = nil
            submit()
        }
    }
}
