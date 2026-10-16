import SwiftUI

/// "Forgot password": sends a reset link. The result never says whether the account exists.
struct ForgotPasswordSheet: View {
    @Bindable var viewModel: AuthViewModel

    @State private var email: String
    @State private var isSending = false
    @FocusState private var isFocused: Bool
    @Environment(\.dismiss) private var dismiss

    init(viewModel: AuthViewModel) {
        self.viewModel = viewModel
        _email = State(initialValue: viewModel.email)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.xl) {
                    AuthHeader(title: "Reset password", subtitle: "We'll email you a link to reset your password.")
                        .padding(.top, Theme.Spacing.lg)
                    UnderlineField(isFocused: isFocused) {
                        TextField("Email address", text: $email,
                                  prompt: UnderlineField<EmptyView>.prompt("Email address", error: nil))
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($isFocused)
                            .submitLabel(.send)
                            .onSubmit(send)
                    }
                    if let message = viewModel.resetMessage {
                        Label(message, systemImage: "envelope")
                            .font(.subheadline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    PrimaryButton(title: "Send reset link", isLoading: isSending, action: send)
                        .textCase(.uppercase)
                        .disabled(email.isEmpty)
                        .opacity(email.isEmpty ? 0.5 : 1)
                }
                .padding(.horizontal, Theme.Spacing.xl)
                .frame(maxWidth: 500)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                }
            }
            .onDisappear { viewModel.clearResetMessage() }
            .onChange(of: viewModel.resetMessage) { _, message in
                if let message { AccessibilityNotification.Announcement(message).post() }
            }
        }
    }

    private func send() {
        guard !isSending, !email.isEmpty else { return }
        isFocused = false
        isSending = true
        Task {
            await viewModel.sendPasswordReset(email: email)
            isSending = false
        }
    }
}
