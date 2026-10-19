import SwiftUI

/// Account: name (applies to new posts), email, type and member since; change password; delete account.
struct AccountView: View {
    let profile: UserProfile
    /// Forgot password (shared with Sign in, so its resend cooldown is the same).
    let passwordReset: PasswordResetModel
    let onDeleteAccount: (String) async throws -> Void

    @Environment(\.appEnvironment) private var environment
    @State private var viewModel: AccountViewModel?

    var body: some View {
        Group {
            if let viewModel {
                AccountForm(viewModel: viewModel, passwordReset: passwordReset)
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
    let passwordReset: PasswordResetModel

    @FocusState private var isNameFocused: Bool
    @State private var isDeleting = false

    var body: some View {
        List {
            Section("Account") {
                LabeledContent(nameLabel) {
                    HStack(spacing: Theme.Spacing.sm) {
                        TextField(nameLabel, text: $viewModel.name)
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(isNameFocused ? Color.primary : Color.secondary)
                            .textContentType(viewModel.isOrganization ? .organizationName : .name)
                            .submitLabel(.done)
                            .focused($isNameFocused)
                            .onSubmit(save)
                            .accessibilityLabel(nameLabel)
                            .accessibilityHint("Edits the name on your new posts")
                        nameAccessory
                    }
                }
                .contentShape(.rect)
                .onTapGesture { isNameFocused = true }
                if let error = viewModel.nameError {
                    Label(error, systemImage: "exclamationmark.circle")
                        .font(.footnote)
                        .foregroundStyle(Theme.Palette.danger)
                } else if case .failed(let message) = viewModel.nameStatus {
                    StatusLine(status: .failed(message))
                }
                LabeledContent("Email") {
                    Text(viewModel.profile.email ?? "")
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                LabeledContent("Member since", value: viewModel.memberSince)
            }

            Section("Security") {
                NavigationLink {
                    ChangePasswordView(viewModel: viewModel, passwordReset: passwordReset)
                } label: {
                    ListRow(title: "Change password", systemImage: "key")
                }
            }

            Section {
                DestructiveButton(title: "Delete account") { isDeleting = true }
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
        }
        .environment(\.defaultMinListRowHeight, 52)
        .scrollDismissesKeyboard(.interactively)
        .animation(.default, value: viewModel.hasNameChanges)
        .animation(.default, value: viewModel.nameStatus)
        .task(id: viewModel.nameStatus) {
            // "Saved" shows briefly, then the pencil comes back.
            guard case .done = viewModel.nameStatus else { return }
            try? await Task.sleep(for: .seconds(AccountViewModel.savedConfirmationSeconds))
            guard !Task.isCancelled else { return }
            viewModel.clearSavedStatus()
        }
        .navigationDestination(isPresented: $isDeleting) {
            DeleteAccountView(viewModel: viewModel)
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { isNameFocused = false }
            }
        }
    }

    private var nameLabel: String { viewModel.isOrganization ? "Organization name" : "Name" }

    /// Pencil = editable. While the name differs from the saved one: Save. Saving: spinner. Saved: a check that
    /// fades back to the pencil.
    @ViewBuilder
    private var nameAccessory: some View {
        Group {
            if viewModel.nameStatus == .working {
                ProgressView()
            } else if viewModel.hasNameChanges {
                Button("Save", action: save)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.Palette.brandPurple)
                    .buttonStyle(.borderless)
                    .disabled(!viewModel.canSaveName)
            } else if case .done = viewModel.nameStatus {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Theme.Palette.success)
                    .accessibilityLabel("Name saved")
            } else {
                Image(systemName: "pencil")
                    .foregroundStyle(Theme.Palette.brandPurple)
                    .accessibilityHidden(true)
            }
        }
        .transition(.opacity)
    }

    private func save() {
        guard viewModel.canSaveName else { return }
        isNameFocused = false
        Task {
            await viewModel.saveName()
            if case .done = viewModel.nameStatus {
                AccessibilityNotification.Announcement("Name saved").post()
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
