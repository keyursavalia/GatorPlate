import SwiftUI

/// About GatorPlate: not an official SFSU app, a link to SFSU Basic Needs, and the version.
struct AboutView: View {
    /// SFSU Basic Needs Initiative (food pantry and CalFresh help).
    private static let basicNeedsURL = URL(string: "https://basicneeds.sfsu.edu")

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Label(AppConfig.appName, systemImage: "fork.knife.circle.fill")
                        .font(.title2.bold())
                        .foregroundStyle(Theme.Palette.brandPurple)
                    Text("Students and student organizations share leftover campus food in seconds, so less goes to waste.")
                        .font(.subheadline)
                }
                .padding(.vertical, Theme.Spacing.xs)
            }
            Section {
                Label("GatorPlate is a student project. It is not an official San Francisco State University app.",
                      systemImage: "info.circle")
                    .font(.subheadline)
                if let url = Self.basicNeedsURL {
                    Link(destination: url) {
                        Label("SFSU Basic Needs: food pantry and CalFresh help", systemImage: "heart.circle")
                    }
                    .frame(minHeight: Theme.Size.minTapTarget)
                }
            }
            Section {
                LabeledContent("Version", value: Self.versionText)
            }
        }
        .navigationTitle("About")
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
