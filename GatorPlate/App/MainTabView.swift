import SwiftUI

/// Main tabs. The Feed arrives in Sprint 06.
struct MainTabView: View {
    let profile: UserProfile
    let onSignOut: () -> Void

    @Environment(\.appEnvironment) private var environment
    @State private var mapViewModel: MapViewModel?

    var body: some View {
        TabView {
            Tab("Map", systemImage: "map") {
                if let mapViewModel {
                    MapScreen(viewModel: mapViewModel)
                }
            }
            Tab("Feed", systemImage: "list.bullet") {
                EmptyState(icon: "list.bullet", title: "Feed", message: "A list of active posts will show up here.")
            }
            Tab("Settings", systemImage: "gearshape") {
                SettingsView(profile: profile, onSignOut: onSignOut)
            }
        }
        .task {
            guard mapViewModel == nil else { return }
            // Sprint 02 shows mock posts; Sprint 06 switches to `environment.posts`.
            mapViewModel = MapViewModel(posts: MockPostService(posts: FoodPost.mockCampus),
                                        location: environment.location)
        }
    }
}
