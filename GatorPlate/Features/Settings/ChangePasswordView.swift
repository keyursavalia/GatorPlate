import SwiftUI

/// Current password, then the new one twice. Reauthenticates before changing it.
struct ChangePasswordView: View {
    let viewModel: AccountViewModel

    @State private var current = ""
    @State private var new = ""
    @State private var confirm = ""
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
