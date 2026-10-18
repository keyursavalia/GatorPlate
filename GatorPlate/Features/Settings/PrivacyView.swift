import SwiftUI

/// What GatorPlate keeps, for how long, and what it never does (RAI data inventory). A three-point summary, then
/// one row per kind of data: title with a short "how long" tag, and one line of detail. Plus the full policy.
struct PrivacyView: View {
    private struct Entry: Identifiable {
        let id: String
        let icon: String
        let title: String
        let detail: String
        /// How long it's kept, a few words.
        let keep: String
    }

    private let kept = [
        Entry(id: "guest", icon: "person.crop.circle.badge.questionmark", title: "Guest browsing",
              detail: "An anonymous ID. No name or email.", keep: "Until sign-up"),
        Entry(id: "account", icon: "person.crop.circle", title: "Your account",
              detail: "Email, name and account type. Only needed to post.", keep: "Until deleted"),
        Entry(id: "alerts", icon: "bell.badge", title: "Notification settings",
              detail: "What you want notifications about. Only you can read them.", keep: "Until changed"),
        Entry(id: "posts", icon: "fork.knife", title: "Posts and photos",
              detail: "Text, place, times and up to 4 food photos.", keep: "24 h after end"),
        Entry(id: "reports", icon: "flag", title: "Reports you send",
              detail: "The post and your reason.", keep: "Until deleted"),
    ]

    private let notKept = [
        Entry(id: "location", icon: "location", title: "Your location",
              detail: "Distances and routes, only while the app is open.", keep: "On device"),
        Entry(id: "ai", icon: "sparkles", title: "AI drafts",
              detail: "Food photos only. No location, name or account.", keep: "Not stored"),
    ]

    private let promises = [
        ("eye.slash", "No tracking"),
        ("scope", "No targeting"),
        ("dollarsign.circle", "No selling"),
    ]

    @State private var showsPolicy = false

    var body: some View {
        List {
            Section {
                summary
            } footer: {
                Text("We never track what you pick up, target notifications by need, or sell your data.")
            }

            Section("What we keep") {
                ForEach(kept) { row($0) }
            }

            Section("Used, never kept") {
                ForEach(notKept) { row($0) }
            }

            Section {
                Button { showsPolicy = true } label: {
                    ListRow(title: LegalDocument.Kind.privacy.title, systemImage: "lock.doc", showsDisclosure: true)
                }
            }
        }
        .navigationTitle("Your privacy")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showsPolicy) {
            LegalDocumentSheet(kind: .privacy) { showsPolicy = false }
        }
    }

    /// Three promises side by side; they stack at large text sizes.
    private var summary: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 0) {
                ForEach(promises, id: \.1) { icon, text in
                    promise(icon: icon, text: text).frame(maxWidth: .infinity)
                }
            }
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                ForEach(promises, id: \.1) { icon, text in
                    HStack(spacing: Theme.Spacing.md) {
                        Image(systemName: icon).foregroundStyle(Theme.Palette.brandPurple).accessibilityHidden(true)
                        Text(text).font(.subheadline.weight(.semibold))
                    }
                }
            }
        }
        .padding(.vertical, Theme.Spacing.sm)
        .accessibilityElement(children: .combine)
    }

    private func promise(icon: String, text: String) -> some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(Theme.Palette.brandPurple)
                .accessibilityHidden(true)
            Text(text)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.center)
        }
    }

    private func row(_ entry: Entry) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.md) {
            Image(systemName: entry.icon)
                .foregroundStyle(Theme.Palette.brandPurple)
                .frame(minWidth: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(entry.title).font(.headline)
                        Spacer(minLength: Theme.Spacing.sm)
                        tag(entry.keep)
                    }
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text(entry.title).font(.headline)
                        tag(entry.keep)
                    }
                }
                Text(entry.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(entry.title). \(entry.detail) \(entry.keep).")
    }

    /// Every tag is as wide as the longest one, so the capsules line up down the page (and still grow with
    /// Dynamic Type): the hidden texts size the capsule, the visible one sits centered in it.
    private func tag(_ text: String) -> some View {
        ZStack {
            ForEach(Array(Set((kept + notKept).map(\.keep))), id: \.self) { Text($0).hidden() }
            Text(text)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(Theme.Palette.brandPurple)
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, 3)
        .background(Theme.Palette.brandPurple.opacity(0.14), in: .capsule)
        .fixedSize()
    }
}

#Preview {
    NavigationStack { PrivacyView() }
}

#Preview("AX5") {
    NavigationStack { PrivacyView() }.dynamicTypeSize(.accessibility5)
}
