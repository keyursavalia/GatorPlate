import SwiftUI

/// Settings > Notifications > Custom notifications (reachable only while notifications are on). An "All free food"
/// switch (on by default) above checklists that are always shown: diet, places, favorite foods (with "+ Custom")
/// and allergens to avoid (`FoodPickSections`, shared with the Map/Feed filter). Picking anything slides the switch
/// off. Switching it off with nothing picked stays on and explains why in an alert. Every change saves on its own a
/// moment later.
struct AlertFiltersView: View {
    @State private var viewModel: AlertFiltersViewModel
    /// Switched off with nothing picked.
    @State private var showsPickAlert = false
    @State private var picksPresentation = FoodPickPresentation()
    @State private var foodError: String?

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
                Text(viewModel.summary)
            }

            if let error = viewModel.errorMessage {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(Theme.Palette.danger)
                    Button("Try again") { viewModel.scheduleSave() }
                }
            }

            FoodPickSections(picks: $viewModel.draft, presentation: $picksPresentation, wording: .notifications,
                             foodError: foodError)

            Section {
                NoteRow(text: "These only choose which notifications you get. AI labels can be wrong, so always confirm with the host.",
                        systemImage: "sparkles")
            }
        }
        .environment(\.defaultMinListRowHeight, 48)
        .environment(\.listAccent, Theme.Palette.accent)
        .foodPickPresentations($picksPresentation, picks: $viewModel.draft, wording: .notifications,
                               foodError: $foodError)
        .navigationTitle("Custom notifications")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: viewModel.draft) { viewModel.scheduleSave() }
        .onDisappear { viewModel.flush() }
        .onChange(of: viewModel.summary) { _, summary in
            AccessibilityNotification.Announcement(summary).post()
        }
        .alert("Pick what you want", isPresented: $showsPickAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("To get fewer notifications, pick a diet, place, food or allergen below. \"All free food\" turns off on its own.")
        }
    }

    // MARK: Actions

    /// Stays on until something is picked: switching it off with nothing picked shows an alert instead.
    private var allFoodBinding: Binding<Bool> {
        Binding(get: { !viewModel.isCustom },
                set: { isOn in
                    guard !isOn, !viewModel.hasSelections else {
                        viewModel.setCustom(!isOn)
                        return
                    }
                    showsPickAlert = true
                })
    }
}
