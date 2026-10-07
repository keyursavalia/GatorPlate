import SwiftUI

/// Main tabs. The Feed arrives in Sprint 06.
struct MainTabView: View {
    let profile: UserProfile
    let onSignOut: () -> Void

    @Environment(\.appEnvironment) private var environment
    @State private var mapViewModel: MapViewModel?
    @State private var isPostFlowPresented = false

    var body: some View {
        TabView {
            Tab("Map", systemImage: "map") {
                if let mapViewModel {
                    MapScreen(viewModel: mapViewModel) { isPostFlowPresented = true }
                }
            }
            Tab("Feed", systemImage: "list.bullet") {
                EmptyState(icon: "list.bullet", title: "Feed", message: "A list of active posts will show up here.")
                    .overlay(alignment: .bottomTrailing) {
                        PostFAB { isPostFlowPresented = true }
                            .padding(Theme.Spacing.lg)
                    }
            }
            Tab("Settings", systemImage: "gearshape") {
                SettingsView(profile: profile, onSignOut: onSignOut)
            }
        }
        .fullScreenCover(isPresented: $isPostFlowPresented) {
            PostFlowCoordinator(camera: environment.camera, analyzer: environment.analyzer)
        }
        .task {
            guard mapViewModel == nil else { return }
            // Sprint 02 shows mock posts; Sprint 06 switches to `environment.posts`.
            mapViewModel = MapViewModel(posts: MockPostService(posts: FoodPost.mockCampus),
                                        location: environment.location)
        }
    }
}
