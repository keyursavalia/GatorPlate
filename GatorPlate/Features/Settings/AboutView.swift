import SwiftUI

/// About GatorPlate: what it is, how it works in three steps, that it isn't an official SFSU app, and the version.
/// Fits one screen; it scrolls only when large text needs it.
struct AboutView: View {
    private struct Step: Identifiable {
        let id: String
        let icon: String
        let title: String
        let detail: String
    }

    private let steps = [
        Step(id: "snap", icon: "camera", title: "Snap the leftovers",
             detail: "Students photograph extra food after an event."),
        Step(id: "draft", icon: "sparkles", title: "AI drafts the post",
             detail: "Items, diet and allergens, reviewed by the poster."),
        Step(id: "find", icon: "map", title: "Students find it",
             detail: "Live on the map, with notifications and Apple Maps directions."),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.xxl) {
                header
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    ForEach(steps) { step in
                        HStack(alignment: .top, spacing: Theme.Spacing.md) {
                            Image(systemName: step.icon)
                                .font(.title3)
                                .foregroundStyle(Theme.Palette.brandPurple)
                                .frame(width: 32)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(step.title).font(.headline)
                                Text(step.detail).font(.subheadline).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                .padding(Theme.Spacing.lg)
                .background(.background.secondary, in: .rect(cornerRadius: Theme.Radius.card))

                Text("A student project, free for everyone on campus. Not an official San Francisco State University app.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.vertical, Theme.Spacing.lg)
            .frame(maxWidth: 500)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "fork.knife.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(Theme.Palette.brandPurple)
                .accessibilityHidden(true)
            Text(AppConfig.appName)
                .font(.largeTitle.weight(.heavy).width(.condensed))
                .textCase(.uppercase)
                .accessibilityAddTraits(.isHeader)
            Text("Leftover campus food, shared in seconds, so less goes to waste.")
                .font(.body)
                .multilineTextAlignment(.center)
            Text("Version \(Self.versionText)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .padding(.top, Theme.Spacing.xs)
        }
    }

    private static var versionText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }
}

#Preview {
    NavigationStack { AboutView() }
}

#Preview("AX5") {
    NavigationStack { AboutView() }.dynamicTypeSize(.accessibility5)
}
