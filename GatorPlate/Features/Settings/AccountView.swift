import SwiftUI

/// Account: name (applies to new posts), email, type and member since; change password; delete account.
struct AccountView: View {
    let profile: UserProfile
    let onDeleteAccount: (String) async throws -> Void

    @Environment(\.appEnvironment) private var environment
    @State private var viewModel: AccountViewModel?

    var body: some View {
        Group {
            if let viewModel {
                AccountForm(viewModel: viewModel)
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard viewModel == nil else { return }
            viewModel = AccountViewModel(profile: profile, account: environment.account, auth: environment.auth,
                                         onDelete: onDeleteAccount)
        }
    }
}

private struct AccountForm: View {
    @Bindable var viewModel: AccountViewModel

    var body: some View {
        List {
            Section {
                TextField(viewModel.isOrganization ? "Organization name" : "Name", text: $viewModel.name)
                    .textContentType(viewModel.isOrganization ? .organizationName : .name)
                    .submitLabel(.done)
                    .onSubmit { Task { await viewModel.saveName() } }
                    .accessibilityLabel(viewModel.isOrganization ? "Organization name" : "Name")
                if let error = viewModel.nameError {
                    Label(error, systemImage: "exclamationmark.circle")
                        .font(.footnote)
                        .foregroundStyle(Theme.Palette.danger)
                }
                Button {
                    Task { await viewModel.saveName() }
                } label: {
                    HStack(spacing: Theme.Spacing.sm) {
                        Text("Save name")
                        if viewModel.nameStatus == .working { ProgressView() }
                    }
                }
                .disabled(!viewModel.canSaveName)
                .frame(minHeight: Theme.Size.minTapTarget)
                StatusLine(status: viewModel.nameStatus)
            } header: {
                Text("Profile")
            } footer: {
                Text("Changes apply to new posts. Posts already live keep the old name.")
            }

            Section("Account") {
                LabeledContent("Email") {
                    HStack(spacing: Theme.Spacing.xs) {
                        Text(viewModel.profile.email)
                        if AppConfig.requireEmailVerification {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(Theme.Palette.success)
                                .accessibilityLabel("verified")
                        }
                    }
                }
                LabeledContent("Account type", value: viewModel.isOrganization ? "Student organization" : "Student")
                LabeledContent("Member since", value: viewModel.memberSince)
            }

            Section("Security") {
                NavigationLink {
                    ChangePasswordView(viewModel: viewModel)
                } label: {
                    Label("Change password", systemImage: "key")
                }
            }

            Section {
                NavigationLink {
                    DeleteAccountView(viewModel: viewModel)
                } label: {
                    Label("Delete account", systemImage: "trash")
                        .foregroundStyle(Theme.Palette.danger)
                }
            }
        }
    }
}

/// Saved / error line under an account action.
struct StatusLine: View {
    let status: AccountViewModel.Status

    var body: some View {
        switch status {
        case .done(let message):
            Label(message, systemImage: "checkmark.circle.fill")
                .font(.footnote)
                .foregroundStyle(Theme.Palette.success)
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.footnote)
                .foregroundStyle(Theme.Palette.danger)
        case .idle, .working:
            EmptyView()
        }
    }
}
