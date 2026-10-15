import SwiftUI

/// What GatorPlate stores, where, and for how long (RAI data inventory). Plain language, read-only.
struct PrivacyView: View {
    private struct Entry: Identifiable {
        let id = UUID()
        let icon: String
        let what: String
        let detail: String
    }

    private let entries = [
        Entry(icon: "person.crop.circle", what: "Your account",
              detail: "Email, name, account type and organization name. Kept until you delete your account."),
        Entry(icon: "bell.badge", what: "Alert settings",
              detail: "Whether alerts are on, quiet hours, this device's alert registration, and your \"What to alert me about\" choices. These can reveal diet or allergies, so only you can read them. They're never shown to others, never logged, never used for ranking. Kept until you change them or delete your account."),
        Entry(icon: "fork.knife", what: "Your posts and photos",
              detail: "Text, place and times, and up to 4 food photos. Deleted 24 hours after a post ends, or right away if you delete your account."),
        Entry(icon: "flag", what: "Reports you send",
              detail: "The post and your reason. Deleted if you delete your account."),
        Entry(icon: "location", what: "Your location",
              detail: "Used only on your phone, only while the app is open, to show distances and routes. Never stored or shared."),
        Entry(icon: "sparkles", what: "AI drafts",
              detail: "Food photos go to Google's Gemini through Firebase to draft a post. Photos carry no location or camera details, and requests carry no name or account."),
    ]

    var body: some View {
        List {
            Section {
                ForEach(entries) { entry in
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Label(entry.what, systemImage: entry.icon).font(.headline)
                        Text(entry.detail).font(.subheadline).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, Theme.Spacing.xs)
                    .accessibilityElement(children: .combine)
                }
            } footer: {
                Text("GatorPlate never tracks what you pick up. Alerts go to everyone whose own filters match; nothing is targeted by need.")
            }
        }
        .navigationTitle("Privacy")
    }
}

#Preview {
    NavigationStack { PrivacyView() }
}
