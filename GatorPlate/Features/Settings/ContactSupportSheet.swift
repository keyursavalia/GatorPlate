import SwiftUI

/// Shown when no mail app can open the support address: the address, selectable, with a Copy button.
struct ContactSupportSheet: View {
    let email: String
    @State private var copied = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    Text("Email us at")
                        .font(.headline)
                    Text(email)
                        .font(.title3.weight(.semibold))
                        .textSelection(.enabled)
                        .accessibilityLabel("Support email: \(email)")
                    Text("We read every message and reply as soon as we can. Reports of offensive posts are reviewed within 24 hours.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    PrimaryButton(title: copied ? "Copied" : "Copy address") {
                        Clipboard.copy(email)
                        copied = true
                        AccessibilityNotification.Announcement("Address copied").post()
                    }
                }
                .padding(Theme.Spacing.xl)
            }
            .scrollBounceBehavior(.basedOnSize)
            .navigationTitle("Contact support")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    Color.clear.sheet(isPresented: .constant(true)) {
        ContactSupportSheet(email: AppConfig.supportEmail)
    }
}

#Preview("AX5") {
    ContactSupportSheet(email: AppConfig.supportEmail)
        .dynamicTypeSize(.accessibility5)
}
