import SwiftUI

/// Tabs for Map, Feed and Settings. Owns the shared models: the posts listener lives exactly as long as this view,
/// which exists only while signed in, so signing out stops it.
struct MainTabView: View {
    let profile: UserProfile

    @Environment(\.appEnvironment) private var environment

    @State private var isPostFlowPresented = false
    @State private var navigation: NavigationModel
    @State private var repository: PostsRepository
    @State private var location: UserLocationModel
    @State private var mapModel: MapViewModel
    @State private var feedModel: FeedViewModel

    init(profile: UserProfile, environment: AppEnvironment = .mock) {
        self.profile = profile
        let navigation = NavigationModel()
        let repository = PostsRepository(service: environment.posts)
        let location = UserLocationModel(location: environment.location)
        _navigation = State(initialValue: navigation)
        _repository = State(initialValue: repository)
        _location = State(initialValue: location)
        _mapModel = State(initialValue: MapViewModel(
            repository: repository,
            location: location,
            navigation: navigation,
            routing: environment.routing,
            actions: PostActionsModel(service: environment.posts, currentUserID: profile.uid)
        ))
        _feedModel = State(initialValue: FeedViewModel(
            repository: repository,
            location: location,
            navigation: navigation
        ))
    }

    var body: some View {
        TabView(selection: $navigation.tab) {
            Tab("Map", systemImage: "map", value: NavigationModel.AppTab.map) {
                CampusMapView(viewModel: mapModel)
                    .postFAB { isPostFlowPresented = true }
            }
            Tab("Feed", systemImage: "list.bullet", value: NavigationModel.AppTab.feed) {
                FeedView(viewModel: feedModel)
                    .postFAB { isPostFlowPresented = true }
            }
            Tab("Settings", systemImage: "gearshape", value: NavigationModel.AppTab.settings) {
                SettingsView(profile: profile)
            }
        }
        .fullScreenCover(isPresented: $isPostFlowPresented) {
            PostFlowView(camera: environment.camera, profile: profile, onViewMap: { navigation.tab = .map })
        }
        // Start when the signed-in UI appears; sign-out removes this view and cancels the task, which stops the listener.
        .task { await repository.run() }
        // Location runs only on Map and Feed (distances), never on Settings.
        .task(id: navigation.tab != .settings) {
            if navigation.tab != .settings { await location.run() }
        }
        .onChange(of: repository.posts) { mapModel.postsChanged() }
        .onChange(of: repository.hasLoaded) { mapModel.postsChanged() }
        .onChange(of: navigation.selectedPostID) { mapModel.selectionChanged() }
    }
}

private extension View {
    /// Pins the Post button bottom-trailing, above the tab bar.
    func postFAB(action: @escaping () -> Void) -> some View {
        safeAreaInset(edge: .bottom, alignment: .trailing) {
            PostFAB(action: action)
                .padding(Theme.Spacing.l)
        }
    }
}

#Preview {
    MainTabView(profile: SampleData.profile)
        .environment(AuthViewModel(auth: MockAuthService(), initialState: .signedIn(SampleData.profile)))
        .environment(\.appEnvironment, .mock)
}
