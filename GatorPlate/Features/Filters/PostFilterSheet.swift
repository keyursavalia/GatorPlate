import SwiftUI

/// "Filters", shared by the Map and the Feed (one filter for both). Picks apply as they're made (no Apply button);
/// the line at the bottom says how many posts show. The Feed adds a Sort section at the top.
struct PostFilterSheet: View {
    @Bindable var store: PostFilterStore
    let browse: BrowseResults
    let showsSort: Bool
    /// The student's Custom notifications picks, or nil when notifications are for all free food.
    let notificationPicks: AlertFilters?

    @State private var picksPresentation = FoodPickPresentation()
    @State private var foodError: String?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        NavigationStack {
            List {
                if showsSort { sortSection }
                if let notificationPicks {
                    Section {
                        Button("Use my notification filters", systemImage: "bell.badge") {
                            store.filter.copyPicks(from: notificationPicks)
                        }
                        .foregroundStyle(Theme.Palette.accent)
                    } footer: {
                        Text("Copies your Custom notifications picks. Changing one never changes the other.")
                    }
                }
                FoodPickSections(picks: $store.filter.picks, presentation: $picksPresentation, wording: .browse,
                                 foodError: foodError)
                timeLeftSection
                distanceSection
                Section {
                    NoteRow(text: "AI labels can be wrong. Always confirm diet and allergens with the host.",
                            systemImage: "sparkles")
                }
            }
            .environment(\.defaultMinListRowHeight, 48)
            .environment(\.listAccent, Theme.Palette.accent)
            .foodPickPresentations($picksPresentation, picks: $store.filter.picks, wording: .browse,
                                   foodError: $foodError)
            .safeAreaInset(edge: .bottom) { resultLine }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Reset") { store.clear() }
                        .disabled(store.filter.isEmpty)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .task(id: resultText) {
            // Spoken politely once the picks settle, not on every tap.
            try? await Task.sleep(for: .seconds(AppConfig.browseAnnouncementDelaySeconds))
            guard !Task.isCancelled else { return }
            var announcement = AttributedString(resultText)
            announcement.accessibilitySpeechAnnouncementPriority = .low
            AccessibilityNotification.Announcement(announcement).post()
        }
    }

    // MARK: Sections

    private var sortSection: some View {
        Section {
            ForEach(FeedSort.allCases, id: \.self) { sort in
                let unavailable = sort == .nearest && browse.userLocation == nil
                CheckRow(title: sort.title, isSelected: store.sort == sort) { store.sort = sort }
                    .disabled(unavailable)
            }
        } header: {
            Text("Sort")
        } footer: {
            if browse.userLocation == nil { Text("Turn on location to sort by nearest.") }
        }
    }

    private var timeLeftSection: some View {
        Section {
            optionPicker("Time left", selection: $store.filter.minMinutesLeft,
                         options: AppConfig.browseFilterMinutesLeftOptions,
                         label: { "\($0)+ min" }, spoken: { "\($0) minutes or more" })
        } header: {
            Text("Time left")
        }
    }

    private var distanceSection: some View {
        Section {
            optionPicker("Walking distance", selection: $store.filter.maxWalkMinutes,
                         options: AppConfig.browseFilterWalkMinutesOptions,
                         label: { "\($0) min" }, spoken: { "Within a \($0) minute walk" })
        } header: {
            Text("Walking distance")
        } footer: {
            if browse.userLocation == nil {
                Text("Turn on location to filter by distance.")
            } else {
                Text("Straight-line estimate from where you are.")
            }
        }
    }

    /// Segmented normally; checkmark rows at accessibility sizes, where segments would clip.
    @ViewBuilder
    private func optionPicker(_ title: String, selection: Binding<Int?>, options: [Int],
                              label: @escaping (Int) -> String, spoken: @escaping (Int) -> String) -> some View {
        let picker = Picker(title, selection: selection) {
            Text("Any").tag(Int?.none)
            ForEach(options, id: \.self) { value in
                Text(label(value)).tag(Int?.some(value))
                    .accessibilityLabel(spoken(value))
            }
        }
        if dynamicTypeSize.isAccessibilitySize {
            picker.pickerStyle(.inline).labelsHidden()
        } else {
            picker.pickerStyle(.segmented)
        }
    }

    // MARK: Result

    private var resultText: String {
        let result = browse.preview(store.filter)
        return "Showing \(result.posts.count) of \(result.totalCount) posts"
    }

    private var resultLine: some View {
        Text(resultText)
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.md)
            .background(.bar)
            .accessibilityAddTraits(.updatesFrequently)
    }
}
