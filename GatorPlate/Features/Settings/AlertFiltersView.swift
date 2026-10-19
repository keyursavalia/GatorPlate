import SwiftUI

/// Settings > Notifications > Custom notifications (reachable only while notifications are on). An "All free food"
/// switch (on by default) above checklists that are always shown: diet, places, favorite foods (with "+ Custom")
/// and allergens to avoid (`FoodPickSections`, shared with the Map/Feed filter). Picking anything slides the switch off; it can't be turned off with nothing picked. Every change saves on its own a moment later.
struct AlertFiltersView: View {
    @State private var viewModel: AlertFiltersViewModel
    /// Turned off with nothing picked: shown off for a moment, then it springs back on.
    @State private var isBouncingOff = false
    @State private var showsPickHint = false

    init(settings: SettingsViewModel) {
        _viewModel = State(initialValue: AlertFiltersViewModel(settings: settings))
    }

    var body: some View {
        List {
            Section {
                Toggle("All free food", isOn: allFoodBinding)
                    .font(.body.weight(.semibold))
                    // Slides off on its own when something below is picked.
                    .animation(.default, value: viewModel.isCustom)
                    .accessibilityHint(viewModel.isCustom ? "Clears your picks" : "Pick categories below to customize")
            } footer: {
                Text(showsPickHint ? "Pick a category below to get only those notifications." : viewModel.summary)
                    .animation(.default, value: showsPickHint)
            }

            if let error = viewModel.errorMessage {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(Theme.Palette.danger)
                    Button("Try again") { viewModel.scheduleSave() }
                }
            }

            FoodPickSections(picks: $viewModel.draft, wording: .notifications)

            Section {
                NoteRow(text: "These only choose which notifications you get. AI labels can be wrong, so always confirm with the host.",
                        systemImage: "sparkles")
            }
        }
        .environment(\.defaultMinListRowHeight, 48)
        .environment(\.listAccent, Theme.Palette.accent)
        .navigationTitle("Custom notifications")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: viewModel.draft) { viewModel.scheduleSave() }
        .onDisappear { viewModel.flush() }
        .onChange(of: viewModel.summary) { _, summary in
            AccessibilityNotification.Announcement(summary).post()
        }
    }

    // MARK: Actions

    /// Stays on until something is picked: switching it off with nothing picked springs back with a hint.
    private var allFoodBinding: Binding<Bool> {
        Binding(get: { !viewModel.isCustom && !isBouncingOff },
                set: { isOn in
                    guard !isOn, !viewModel.hasSelections else {
                        viewModel.setCustom(!isOn)
                        return
                    }
                    bounceBack()
                })
    }

    private func bounceBack() {
        isBouncingOff = true
        showsPickHint = true
        AccessibilityNotification.Announcement("Pick a category below to get only those notifications.").post()
        Task {
            try? await Task.sleep(for: .milliseconds(350))
            withAnimation { isBouncingOff = false }
            try? await Task.sleep(for: .seconds(3))
            showsPickHint = false
        }
    }
}
