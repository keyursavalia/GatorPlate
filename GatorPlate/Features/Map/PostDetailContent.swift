import SwiftUI

/// The post as students read it, shared by the map sheet and Review's Preview. Top to bottom, most useful first:
/// the photos (whole, never cropped), title and poster, three facts (time left, walk, servings), Open in Apple
/// Maps, then grouped rows like Settings: where, what's there, diet and allergens, heads-up notes, poster actions.
/// The same layout at every sheet height.
struct PostDetailContent<MenuContent: View, Actions: View>: View {
    let post: FoodPost
    let photoSources: [PostPhotoSource]
    let images: PostImageCache?
    /// Straight-line meters from the user, when known.
    let distanceMeters: Double?
    let showCalories: Bool
    /// Nil in Review's Preview (nothing to open yet).
    var onOpenInMaps: (() -> Void)?
    /// "Hidden by your filters": the post was opened on purpose although the Map/Feed filter hides it.
    var filterNote: String?
    @ViewBuilder var menu: MenuContent
    @ViewBuilder var actions: Actions

    var body: some View {
        List {
            Section {
                header
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)

            Section {
                facts
            }

            if let filterNote {
                Section {
                    NoteRow(text: filterNote, systemImage: "line.3.horizontal.decrease")
                }
            }

            if let onOpenInMaps {
                Section {
                    PrimaryButton(title: "Open in Apple Maps", action: onOpenInMaps)
                        .accessibilityHint("Walking directions in Apple Maps")
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            Section("Where") {
                ListRow(title: post.locationName, systemImage: "mappin.and.ellipse", subtitle: post.locationDetail)
            }

            whatSection
            dietSection

            if !post.cautions.isEmpty {
                Section("Heads up") {
                    ForEach(post.cautions, id: \.self) { caution in
                        ListRow(title: caution, systemImage: "exclamationmark.shield", iconTint: Theme.Palette.warning)
                    }
                }
            }

            actions
        }
        .listSectionSpacing(.compact)
        .environment(\.defaultMinListRowHeight, 48)
        .environment(\.listAccent, Theme.Palette.accent)
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            if !photoSources.isEmpty {
                PhotoCarousel(sources: photoSources, images: images)
            }
            HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(post.title)
                        .font(.title3.bold())
                        .accessibilityAddTraits(.isHeader)
                    Text(posterName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                menu
            }
            .padding(.horizontal, Theme.Spacing.xs)
        }
        .padding(.top, Theme.Spacing.sm)
    }

    /// Time left, walk and servings side by side, like the Privacy summary. Stacks at large text sizes.
    private var facts: some View {
        TimelineView(CountdownSchedule(expiresAt: post.expiresAt)) { context in
            let minutes = TimeRemainingPill.minutesLeft(until: post.expiresAt, now: context.date)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 0) { factViews(minutes: minutes) }
                VStack(alignment: .leading, spacing: Theme.Spacing.md) { factViews(minutes: minutes) }
            }
            .padding(.vertical, Theme.Spacing.xs)
        }
    }

    @ViewBuilder
    private func factViews(minutes: Int) -> some View {
        Fact(value: "\(minutes) min", caption: "left", systemImage: "clock",
             tint: minutes < 10 ? Theme.Palette.warning : Theme.Palette.accent)
        if let walk = distanceMeters.map(DistanceText.walkMinutes(meters:)) {
            Fact(value: "\(walk) min", caption: "walk", systemImage: "figure.walk")
        }
        if let servings = post.estimatedServings {
            Fact(value: "~\(servings)", caption: "servings", systemImage: "person.2")
        }
    }

    // MARK: Sections

    @ViewBuilder
    private var whatSection: some View {
        if !post.description.isEmpty || !post.items.isEmpty {
            Section("What's there") {
                if !post.description.isEmpty {
                    Text(post.description)
                }
                ForEach(Array(post.items.enumerated()), id: \.offset) { _, item in
                    ListRow(title: item.name, systemImage: item.dietary.icon,
                            value: post.aiGenerated ? item.dietary.estimateLabel : item.dietary.label,
                            iconTint: item.dietary.tint)
                }
            }
        }
    }

    private var dietSection: some View {
        Section {
            ListRow(title: "Diet", systemImage: post.overallDietary.icon,
                    value: post.aiGenerated ? post.overallDietary.estimateLabel : post.overallDietary.label,
                    iconTint: post.overallDietary.tint)
            if post.allergenWarnings.isEmpty {
                ListRow(title: "Allergens", systemImage: "questionmark.circle", value: "Not listed",
                        iconTint: Theme.Palette.warning)
            } else {
                ListRow(title: "May contain", systemImage: "exclamationmark.triangle",
                        subtitle: post.allergenWarnings.map(\.displayName).joined(separator: ", "),
                        iconTint: Theme.Palette.warning)
            }
            if showCalories, let calories {
                ListRow(title: "Calories", systemImage: "flame", value: calories)
            }
        } header: {
            Text("Diet & allergens")
        } footer: {
            Text(post.aiGenerated
                 ? "Estimated by AI and unverified. Confirm allergens and ingredients with the host."
                 : "Unverified. Confirm allergens and ingredients with the host.")
        }
    }

    // MARK: Text

    private var posterName: String {
        post.orgName ?? post.authorName
    }

    /// "420–520 kcal" per serving across items that have an estimate.
    private var calories: String? {
        let ranges = post.items.compactMap(\.calories)
        guard let low = ranges.map(\.low).min(), let high = ranges.map(\.high).max() else { return nil }
        return "\(low)–\(high) kcal"
    }
}

/// One of the three facts under the title: icon, value, caption.
private struct Fact: View {
    let value: String
    let caption: String
    let systemImage: String
    var tint: Color = Theme.Palette.accent

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: systemImage)
                .font(.subheadline)
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            Text(value)
                .font(.headline.monospacedDigit())
            Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(value) \(caption)")
    }
}
