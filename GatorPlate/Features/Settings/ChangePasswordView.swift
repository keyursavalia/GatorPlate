import SwiftUI

/// Current password, then the new one twice, as inset-grouped rows with icons like Account and Delete account.
/// A live checklist shows the rules; the filled button reauthenticates and changes it. "Forgot your current
/// password?" sends a reset link to the account's email and shows the same "Check your email" as Sign in.
struct ChangePasswordView: View {
    let viewModel: AccountViewModel
    let passwordReset: PasswordResetModel

    private enum Field: Hashable { case current, new, confirm }

    @State private var current = ""
    @State private var new = ""
    @State private var confirm = ""
    @State private var showsReset = false
    @FocusState private var focus: Field?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                PasswordRow(title: "Current password", systemImage: "lock", text: $current,
                            contentType: .password)
                    .focused($focus, equals: .current)
                    .submitLabel(.next)
            } header: {
                Text("Current password")
            } footer: {
                if let email = viewModel.profile.email {
                    Button("Forgot your current password?") { showsReset = true }
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.Palette.accent)
                        .frame(minHeight: Theme.Size.minTapTarget)
                        .accessibilityHint("Emails a reset link to \(email)")
                        .sheet(isPresented: $showsReset) {
                            ForgotPasswordSheet(model: passwordReset, start: .account(email: email))
                        }
                }
            }

            Section {
                PasswordRow(title: "New password", systemImage: "key", text: $new, contentType: .newPassword)
                    .focused($focus, equals: .new)
                    .submitLabel(.next)
                PasswordRow(title: "Confirm new password", systemImage: "key", text: $confirm,
                            contentType: .newPassword)
                    .focused($focus, equals: .confirm)
                    .submitLabel(.go)
            } header: {
                Text("New password")
            } footer: {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    RuleLine(text: "At least \(AppConfig.minPasswordLength) characters",
                             isMet: Validation.isPasswordValid(new))
                    RuleLine(text: "Passwords match", isMet: !confirm.isEmpty && new == confirm)
                }
                .padding(.top, Theme.Spacing.xs)
            }

            Section {
                VStack(spacing: Theme.Spacing.md) {
                    PrimaryButton(title: "Change password", isLoading: viewModel.passwordStatus == .working,
                                  action: submit)
                        .textCase(.uppercase)
                        .disabled(!canSubmit)
                        .opacity(canSubmit ? 1 : 0.5)
                    StatusLine(status: viewModel.passwordStatus)
                }
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
        }
        .environment(\.defaultMinListRowHeight, 52)
        .scrollDismissesKeyboard(.interactively)
        .onSubmit(next)
        .navigationTitle("Change password")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var canSubmit: Bool {
        !current.isEmpty && Validation.isPasswordValid(new) && new == confirm && viewModel.passwordStatus != .working
    }

    /// Return moves current -> new -> confirm, then submits.
    private func next() {
        switch focus {
        case .current: focus = .new
        case .new: focus = .confirm
        case .confirm, nil: submit()
        }
    }

    private func submit() {
        guard canSubmit else { return }
        focus = nil
        Task {
            if await viewModel.changePassword(current: current, new: new, confirm: confirm) {
                AccessibilityNotification.Announcement("Password changed").post()
                dismiss()
            }
        }
    }
}

/// One password field in a list row: a fixed-width icon, the field with a visible placeholder, and an eye toggle.
private struct PasswordRow: View {
    let title: String
    let systemImage: String
    @Binding var text: String
    let contentType: UITextContentType

    @State private var isRevealed = false
    @ScaledMetric(relativeTo: .body) private var iconWidth: CGFloat = 28

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: systemImage)
                .foregroundStyle(Theme.Palette.brandPurple)
                .frame(width: iconWidth)
                .accessibilityHidden(true)
            Group {
                if isRevealed {
                    TextField(title, text: $text, prompt: Text(title))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } else {
                    SecureField(title, text: $text, prompt: Text(title))
                }
            }
            .textContentType(contentType)
            Button(isRevealed ? "Hide password" : "Show password",
                   systemImage: isRevealed ? "eye.slash" : "eye") { isRevealed.toggle() }
                .labelStyle(.iconOnly)
                .foregroundStyle(.secondary)
                .buttonStyle(.borderless)
                .frame(minWidth: Theme.Size.minTapTarget, minHeight: Theme.Size.minTapTarget)
        }
    }
}

/// "✓ At least 8 characters": gray until met, then green with a filled check.
private struct RuleLine: View {
    let text: String
    let isMet: Bool

    var body: some View {
        Label(text, systemImage: isMet ? "checkmark.circle.fill" : "circle")
            .font(.footnote)
            .foregroundStyle(isMet ? Theme.Palette.success : .secondary)
            .accessibilityLabel(text)
            .accessibilityValue(isMet ? "Done" : "Not yet")
    }
}
