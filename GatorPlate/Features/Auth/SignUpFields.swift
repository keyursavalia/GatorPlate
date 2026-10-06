import SwiftUI

/// Sign-up-only fields: account type and the matching name field.
struct SignUpFields: View {
    @Bindable var viewModel: AuthViewModel
    var focus: FocusState<AuthFocusField?>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            Picker("Account type", selection: $viewModel.accountType) {
                Text("Student").tag(AccountType.student)
                Text("Student Organization").tag(AccountType.organization)
            }
            .pickerStyle(.segmented)

            if viewModel.accountType == .organization {
                AuthTextField(label: "Organization name", error: viewModel.nameError) {
                    TextField("Organization name", text: $viewModel.orgName)
                        .textContentType(.organizationName)
                        .focused(focus, equals: .name)
                        .submitLabel(.next)
                }
                .onChange(of: viewModel.orgName) { _, newValue in
                    if newValue.count > AppConfig.maxNameLength {
                        viewModel.orgName = String(newValue.prefix(AppConfig.maxNameLength))
                    }
                }
            } else {
                AuthTextField(label: "Name", error: viewModel.nameError) {
                    TextField("Name", text: $viewModel.name)
                        .textContentType(.name)
                        .focused(focus, equals: .name)
                        .submitLabel(.next)
                }
                .onChange(of: viewModel.name) { _, newValue in
                    if newValue.count > AppConfig.maxNameLength {
                        viewModel.name = String(newValue.prefix(AppConfig.maxNameLength))
                    }
                }
            }
        }
    }
}
