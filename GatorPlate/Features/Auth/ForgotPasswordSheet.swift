import SwiftUI

/// "Forgot password?": sends a reset link. The result never says whether the account exists.
struct ForgotPasswordSheet: View {
    @Bindable var viewModel: AuthViewModel

    @State private var email: String
    @State private var isSending = false
    @Environment(\.dismiss) private var dismiss

    init(viewModel: AuthViewModel) {
        self.viewModel = viewModel
        _email = State(initialValue: viewModel.email)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.send)
                        .onSubmit(send)
                } footer: {
                    Text("We'll email a link to reset your password.")
                }
                Section {
                    Button(action: send) {
                        HStack(spacing: Theme.Spacing.sm) {
                            Text("Send reset link")
                            if isSending { ProgressView() }
                        }
                    }
                    .disabled(email.isEmpty || isSending)
                    .frame(minHeight: Theme.Size.minTapTarget)
                    if let message = viewModel.resetMessage {
                        Label(message, systemImage: "envelope")
                            .font(.subheadline)
                            .accessibilityAddTraits(.updatesFrequently)
                    }
                }
            }
            .navigationTitle("Reset password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onDisappear { viewModel.clearResetMessage() }
            .onChange(of: viewModel.resetMessage) { _, message in
                if let message { AccessibilityNotification.Announcement(message).post() }
            }
        }
    }

    private func send() {
        guard !isSending else { return }
        isSending = true
        Task {
            await viewModel.sendPasswordReset(email: email)
            isSending = false
        }
    }
}
