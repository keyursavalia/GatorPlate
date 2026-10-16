import SwiftUI

/// Delete your account (App Store Guideline 5.1.1(v)). Lists what's deleted, asks for the password, then deletes
/// everything on the server. Errors keep the user signed in with a retry.
struct DeleteAccountView: View {
    let viewModel: AccountViewModel

    @State private var password = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("This permanently deletes:").font(.headline)
                    Label("Your profile, alert settings and this device's alert registration", systemImage: "person.crop.circle")
                    Label("Your posts and their photos (active posts disappear for everyone right away)", systemImage: "fork.knife")
                    Label("Reports you've sent", systemImage: "flag")
                    Text("This can't be undone.").font(.subheadline.weight(.semibold))
                }
                .font(.subheadline)
                .padding(.vertical, Theme.Spacing.xs)
                .accessibilityElement(children: .combine)
            }
            Section {
                SecureField("Password", text: $password)
                    .textContentType(.password)
                    .accessibilityHint("Enter your password to confirm")
            } footer: {
                Text("For your security, enter your password to confirm.")
            }
            Section {
                VStack(spacing: Theme.Spacing.md) {
                    StatusLine(status: viewModel.deleteStatus)
                    DestructiveButton(title: "Delete account permanently",
                                      isLoading: viewModel.deleteStatus == .working) {
                        Task { await viewModel.deleteAccount(password: password) }
                    }
                    .disabled(password.isEmpty)
                    .opacity(password.isEmpty ? 0.5 : 1)
                    Button("Cancel") { dismiss() }
                        .frame(minHeight: Theme.Size.minTapTarget)
                        .disabled(viewModel.deleteStatus == .working)
                }
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Delete account")
        .navigationBarTitleDisplayMode(.inline)
        .interactiveDismissDisabled(viewModel.deleteStatus == .working)
        .navigationBarBackButtonHidden(viewModel.deleteStatus == .working)
    }
}
