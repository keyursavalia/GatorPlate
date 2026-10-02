import SwiftUI

/// Sign-up-only fields: account type, then the student's name or the organization's name.
struct SignUpFields: View {
    @Bindable var viewModel: AuthViewModel
    var focus: FocusState<AuthField?>.Binding
    let onSubmit: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Account type")
                    .font(.subheadline.weight(.semibold))
                accountTypePicker
            }

            switch viewModel.accountType {
            case .student:
                AuthTextField(
                    title: "Your name",
                    text: $viewModel.name,
                    kind: .personName,
                    error: viewModel.fieldErrors[.name]
                )
                .focused(focus, equals: .name)
                .submitLabel(.go)
                .onSubmit(onSubmit)
            case .organization:
                AuthTextField(
                    title: "Organization name",
                    text: $viewModel.orgName,
                    kind: .organization,
                    error: viewModel.fieldErrors[.orgName]
                )
                .focused(focus, equals: .orgName)
                .submitLabel(.go)
                .onSubmit(onSubmit)
            }
        }
    }

    @ViewBuilder
    private var accountTypePicker: some View {
        let picker = Picker("Account type", selection: $viewModel.accountType) {
            Text("Student").tag(AccountType.student)
            Text("Student Organization").tag(AccountType.organization)
        }
        // Segments clip at accessibility sizes, so fall back to a menu.
        if dynamicTypeSize.isAccessibilitySize {
            picker.pickerStyle(.menu)
        } else {
            picker.pickerStyle(.segmented).labelsHidden()
        }
    }
}

#Preview("Student") {
    @Previewable @FocusState var focus: AuthField?
    SignUpFields(
        viewModel: AuthViewModel(auth: MockAuthService(), initialState: .signedOut),
        focus: $focus,
        onSubmit: {}
    )
    .padding()
    .environment(\.appEnvironment, .mock)
}

#Preview("Organization, AX3") {
    @Previewable @FocusState var focus: AuthField?
    let viewModel = AuthViewModel(auth: MockAuthService(), initialState: .signedOut)
    viewModel.accountType = .organization
    return SignUpFields(viewModel: viewModel, focus: $focus, onSubmit: {})
        .padding()
        .dynamicTypeSize(.accessibility3)
        .environment(\.appEnvironment, .mock)
}
