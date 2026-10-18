import SwiftUI

/// Current password, then the new one twice. Reauthenticates before changing it. "Forgot your current password?"
/// sends a reset link to the account's email (no typing) and shows the same "Check your email" as Sign in.
struct ChangePasswordView: View {
    let viewModel: AccountViewModel
    let passwordReset: PasswordResetModel

    @State private var current = ""
    @State private var new = ""
    @State private var confirm = ""
    @State private var showsReset = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section {
                SecureField("Current password", text: $current)
                    .textContentType(.password)
                SecureField("New password", text: $new)
                    .textContentType(.newPassword)
                SecureField("New password again", text: $confirm)
                    .textContentType(.newPassword)
            } footer: {
                Text("Use at least \(AppConfig.minPasswordLength) characters.")
            }
            if let email = viewModel.profile.email {
                Section {
                    Button("Forgot your current password?") { showsReset = true }
                        .foregroundStyle(Theme.Palette.brandPurple)
                        .frame(minHeight: Theme.Size.minTapTarget)
                        .accessibilityHint("Emails a reset link to \(email)")
                }
                .sheet(isPresented: $showsReset) {
                    ForgotPasswordSheet(model: passwordReset, start: .account(email: email))
                }
            }
            Section {
                Button {
                    Task {
                        if await viewModel.changePassword(current: current, new: new, confirm: confirm) {
                            AccessibilityNotification.Announcement("Password changed").post()
                            dismiss()
                        }
                    }
                } label: {
                    HStack(spacing: Theme.Spacing.sm) {
                        Text("Change password")
                        if viewModel.passwordStatus == .working { ProgressView() }
                    }
                }
                .disabled(current.isEmpty || new.isEmpty || confirm.isEmpty || viewModel.passwordStatus == .working)
                .frame(minHeight: Theme.Size.minTapTarget)
                StatusLine(status: viewModel.passwordStatus)
            }
        }
        .navigationTitle("Change password")
        .navigationBarTitleDisplayMode(.inline)
    }
}
