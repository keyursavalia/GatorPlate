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

    @FocusState private var isNameFocused: Bool
    @State private var isDeleting = false

    var body: some View {
        List {
            Section {
                HStack(spacing: Theme.Spacing.sm) {
                    TextField(viewModel.isOrganization ? "Organization name" : "Name", text: $viewModel.name)
                        .textContentType(viewModel.isOrganization ? .organizationName : .name)
                        .submitLabel(.done)
                        .focused($isNameFocused)
                        .onSubmit(save)
                        .accessibilityLabel(viewModel.isOrganization ? "Organization name" : "Name")
                    nameAccessory
                }
                .frame(minHeight: Theme.Size.minTapTarget)
                if let error = viewModel.nameError {
                    Label(error, systemImage: "exclamationmark.circle")
                        .font(.footnote)
                        .foregroundStyle(Theme.Palette.danger)
                } else if case .failed(let message) = viewModel.nameStatus {
                    StatusLine(status: .failed(message))
                }
            } header: {
                Text("Profile")
            } footer: {
                Text("Changes apply to new posts. Posts already live keep the old name.")
            }

            Section("Account") {
                LabeledContent("Email") {
                    Text(viewModel.profile.email ?? "")
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                LabeledContent("Account type", value: viewModel.profile.accountType.displayName)
                LabeledContent("Member since", value: viewModel.memberSince)
            }

            Section("Security") {
                NavigationLink {
                    ChangePasswordView(viewModel: viewModel)
                } label: {
                    SettingsRow(title: "Change password", systemImage: "key")
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

    /// Save appears only while the name differs from the saved one; after saving, a "Saved" check replaces it.
    @ViewBuilder
    private var nameAccessory: some View {
        if viewModel.nameStatus == .working {
            ProgressView()
        } else if viewModel.hasNameChanges {
            Button("Save", action: save)
                .font(.subheadline.weight(.semibold))
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .tint(Theme.Palette.brandPurple)
                .disabled(!viewModel.canSaveName)
        } else if case .done(let message) = viewModel.nameStatus {
            Label(message, systemImage: "checkmark.circle.fill")
                .font(.subheadline)
                .foregroundStyle(Theme.Palette.success)
                .accessibilityLabel("Name saved")
        }
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
