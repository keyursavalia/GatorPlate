import SwiftUI

/// What GatorPlate keeps, for how long, and what it never does (RAI data inventory). Short rows to skim, plus the
/// full Privacy Policy.
struct PrivacyView: View {
    private struct Entry: Identifiable {
        let id: String
        let icon: String
        let title: String
        let detail: String
        let retention: String
    }

    private let kept = [
        Entry(id: "guest", icon: "person.crop.circle.badge.questionmark", title: "Guest browsing",
              detail: "An anonymous ID. No name or email.",
              retention: "Until you create an account or reinstall"),
        Entry(id: "account", icon: "person.crop.circle", title: "Your account",
              detail: "Email, name, account type and organization name. Only needed to post.",
              retention: "Until you delete your account"),
        Entry(id: "alerts", icon: "bell.badge", title: "Alert settings",
              detail: "Alerts on or off, quiet hours, this phone's alert ID and what you want alerts about. Only you can read them.",
              retention: "Until you change them"),
        Entry(id: "posts", icon: "fork.knife", title: "Your posts and photos",
              detail: "Text, place, times and up to 4 food photos.",
              retention: "Deleted 24 hours after a post ends"),
        Entry(id: "reports", icon: "flag", title: "Reports you send",
              detail: "The post and your reason.",
              retention: "Deleted with your account"),
    ]

    private let onDevice = [
        Entry(id: "location", icon: "location", title: "Your location",
              detail: "Shows distances and routes while the app is open.",
              retention: "Never stored or shared"),
        Entry(id: "ai", icon: "sparkles", title: "AI drafts",
              detail: "Food photos go to Google's Gemini through Firebase to draft a post. No location, camera details, name or account.",
              retention: "Not kept by GatorPlate"),
    ]

    private let never = [
        ("eye.slash", "Track what food you pick up"),
        ("scope", "Target alerts by need. Your own filters decide."),
        ("dollarsign.circle", "Sell or share your data for ads"),
    ]

    @State private var showsPolicy = false

    var body: some View {
        List {
            Section {
                ForEach(kept) { row($0) }
            } header: {
                Text("What we keep")
            }

            Section {
                ForEach(onDevice) { row($0) }
            } header: {
                Text("Used, not kept")
            }

            Section("We never") {
                ForEach(never, id: \.1) { icon, text in
                    Label {
                        Text(text)
                    } icon: {
                        Image(systemName: icon).foregroundStyle(Theme.Palette.brandPurple)
                    }
                }
            }

            Section {
                Button { showsPolicy = true } label: {
                    SettingsRow(title: LegalDocument.Kind.privacy.title, systemImage: "lock.doc", showsDisclosure: true)
                }
            } footer: {
                Text("Alerts go to everyone whose own filters match; nothing is targeted by need.")
            }
        }
        .navigationTitle("Your privacy")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showsPolicy) {
            LegalDocumentSheet(kind: .privacy) { showsPolicy = false }
        }
    }

    private func row(_ entry: Entry) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.md) {
            Image(systemName: entry.icon)
                .foregroundStyle(Theme.Palette.brandPurple)
                .frame(minWidth: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(entry.title).font(.headline)
                Text(entry.detail).font(.subheadline).foregroundStyle(.secondary)
                Label(entry.retention, systemImage: "clock")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    NavigationStack { PrivacyView() }
}
