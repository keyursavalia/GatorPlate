import SwiftUI

/// Main tabs. The Feed arrives in Sprint 06.
struct MainTabView: View {
    enum TabID: Hashable {
        case map, feed, settings
    }

    let profile: UserProfile
    let onSignOut: () -> Void

    @Environment(\.appEnvironment) private var environment
    @State private var mapViewModel: MapViewModel?
    @State private var isPostFlowPresented = false
    @State private var selectedTab = TabID.map

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Map", systemImage: "map", value: TabID.map) {
                if let mapViewModel {
                    MapScreen(viewModel: mapViewModel) { isPostFlowPresented = true }
                }
            }
            Tab("Feed", systemImage: "list.bullet", value: TabID.feed) {
                EmptyState(icon: "list.bullet", title: "Feed", message: "A list of active posts will show up here.")
                    .overlay(alignment: .bottomTrailing) {
                        PostFAB { isPostFlowPresented = true }
                            .padding(Theme.Spacing.lg)
                    }
            }
            Tab("Settings", systemImage: "gearshape", value: TabID.settings) {
                SettingsView(profile: profile, onSignOut: onSignOut)
            }
        }
        .fullScreenCover(isPresented: $isPostFlowPresented) {
            PostFlowCoordinator(camera: environment.camera, analyzer: environment.analyzer,
                                posts: environment.posts, location: environment.location,
                                author: PostAuthor(profile: profile)) {
                // Sprint 06 shows the real pin; for now this lands on the Map tab.
                selectedTab = .map
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
