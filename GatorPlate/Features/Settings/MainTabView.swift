import SwiftUI

/// Tabs for Map, Feed and Settings. Feed is still a placeholder.
struct MainTabView: View {
    let profile: UserProfile

    @Environment(\.appEnvironment) private var environment
    @State private var isPostFlowPresented = false

    var body: some View {
        TabView {
            Tab("Map", systemImage: "map") {
                CampusMapView(location: environment.location)
                    .postFAB { isPostFlowPresented = true }
            }
            Tab("Feed", systemImage: "list.bullet") {
                placeholder(
                    systemImage: "list.bullet",
                    title: "Feed",
                    message: "A list of active posts will show up here."
                )
                .postFAB { isPostFlowPresented = true }
            }
            Tab("Settings", systemImage: "gearshape") {
                SettingsView(profile: profile)
            }
        }
        .fullScreenCover(isPresented: $isPostFlowPresented) {
            PostFlowView(camera: environment.camera)
        }
    }

    private func placeholder(systemImage: String, title: String, message: String) -> some View {
        NavigationStack {
            EmptyState(systemImage: systemImage, title: title, message: message)
                .frame(maxHeight: .infinity)
                .background(Color.surface)
                .navigationTitle(title)
        }
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
