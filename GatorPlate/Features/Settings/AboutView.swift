import SwiftUI

/// About GatorPlate, in the Welcome screen's style: the app tile, name, tagline and version; "How it works" as a
/// three-step timeline (tinted icon tiles joined by a line); three reasons it exists as tiles; and a note that it's a
/// student project, not an official SFSU app. Steps rise in one after another (fade only with Reduce Motion).
/// Scrolls only when large text needs it; tiles stack at accessibility sizes.
struct AboutView: View {
    private struct Step: Identifiable {
        let id: String
        let icon: String
        let title: String
        let detail: String
        let tint: Color
    }

    private struct Reason: Identifiable {
        let id: String
        let icon: String
        let title: String
        let detail: String
        let tint: Color
    }

    private let steps = [
        Step(id: "snap", icon: "camera.fill", title: "Snap the leftovers",
             detail: "After an event, a student takes a photo of the extra food.", tint: Theme.Palette.accent),
        Step(id: "draft", icon: "sparkles", title: "AI drafts the post",
             detail: "Items, diet and allergens, checked by the poster before it goes live.",
             tint: Theme.Palette.brandPurple),
        Step(id: "find", icon: "map.fill", title: "Students find it",
             detail: "Live on the map with notifications and Apple Maps directions.", tint: Theme.Palette.success),
    ]

    private let reasons = [
        Reason(id: "waste", icon: "leaf.fill", title: "Less waste", detail: "Food gets eaten",
               tint: Theme.Palette.success),
        Reason(id: "free", icon: "gift.fill", title: "Always free", detail: "For all students",
               tint: Theme.Palette.brandGold),
        Reason(id: "private", icon: "lock.shield.fill", title: "Private", detail: "Never tracked",
               tint: Theme.Palette.brandPurple),
    ]

    @State private var hasAppeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .title2) private var stepTile: CGFloat = 44

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.xxl) {
                header
                howItWorks
                reasonTiles
                footnote
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.vertical, Theme.Spacing.lg)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { hasAppeared = true }
    }

    // MARK: Header

    /// The Welcome screen's app tile, the name, the tagline and the version in a capsule.
    private var header: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "fork.knife")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 80, height: 80)
                .background(
                    LinearGradient(colors: [Theme.Palette.brandPurple, Theme.Palette.brandPurple.opacity(0.7)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: .rect(cornerRadius: 20))
                .shadow(color: Theme.Palette.brandPurple.opacity(0.35), radius: 14, y: 6)
                .accessibilityHidden(true)
            VStack(spacing: Theme.Spacing.xs) {
                Text(AppConfig.appName)
                    .font(.largeTitle.weight(.heavy).width(.condensed))
                    .textCase(.uppercase)
                    .accessibilityAddTraits(.isHeader)
                Text("Leftover campus food, shared in seconds, so less goes to waste.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Text("Version \(Self.versionText)")
                .font(.caption.weight(.medium).monospacedDigit())
                .foregroundStyle(.secondary)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.xs)
                .background(.background.secondary, in: .capsule)
        }
        .padding(.top, Theme.Spacing.sm)
    }

    // MARK: How it works

    private var howItWorks: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("How it works")
                .font(.title3.bold())
                .accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                    stepRow(step, number: index + 1, isLast: index == steps.count - 1)
                        .opacity(hasAppeared ? 1 : 0)
                        .offset(y: hasAppeared || reduceMotion ? 0 : 12)
                        .animation(reduceMotion ? .easeOut(duration: 0.3)
                                       : .spring(duration: 0.5).delay(0.1 + Double(index) * 0.12),
                                   value: hasAppeared)
                }
            }
            .padding(Theme.Spacing.lg)
            .background(.background.secondary, in: .rect(cornerRadius: Theme.Radius.card))
        }
    }

    /// A tinted icon tile with a line down to the next step, then "STEP 1", the title and a line of detail.
    private func stepRow(_ step: Step, number: Int, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            VStack(spacing: 0) {
                Image(systemName: step.icon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(step.tint)
                    .frame(width: stepTile, height: stepTile)
                    .background(step.tint.opacity(0.15), in: .rect(cornerRadius: 12))
                if !isLast {
                    Rectangle()
                        .fill(.quaternary)
                        .frame(width: 2)
                        .frame(minHeight: Theme.Spacing.lg, maxHeight: .infinity)
                        .padding(.vertical, Theme.Spacing.xs)
                }
            }
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Step \(number)")
                    .font(.caption.weight(.bold))
                    .textCase(.uppercase)
                    .foregroundStyle(step.tint)
                Text(step.title)
                    .font(.headline)
                Text(step.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, isLast ? 0 : Theme.Spacing.lg)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Reasons

    /// Three tiles side by side; they stack at accessibility sizes.
    private var reasonTiles: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: Theme.Spacing.md))
            : AnyLayout(HStackLayout(alignment: .top, spacing: Theme.Spacing.md))
        return layout {
            ForEach(reasons) { reason in
                VStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: reason.icon)
                        .font(.title2)
                        .foregroundStyle(reason.tint)
                        .accessibilityHidden(true)
                    Text(reason.title)
                        .font(.subheadline.weight(.semibold))
                    // Two lines kept for every tile, so the three line up even if one wraps.
                    Text(reason.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2, reservesSpace: true)
                }
                .multilineTextAlignment(.center)
                .padding(.vertical, Theme.Spacing.lg)
                .padding(.horizontal, Theme.Spacing.sm)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(.background.secondary, in: .rect(cornerRadius: Theme.Radius.card))
                .accessibilityElement(children: .combine)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: Footnote

    private var footnote: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Label("A student project at SF State", systemImage: "graduationcap.fill")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.Palette.brandPurple)
            Text("Free for everyone on campus.\nNot an official San Francisco State University app.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .accessibilityElement(children: .combine)
    }

    /// The App Store version ("1.0"), without the build number.
    private static var versionText: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }
}

#Preview {
    NavigationStack { AboutView() }
}

#Preview("AX5") {
    NavigationStack { AboutView() }.dynamicTypeSize(.accessibility5)
}
