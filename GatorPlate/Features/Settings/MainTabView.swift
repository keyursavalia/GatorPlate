import SwiftUI

/// Tabs for Map, Feed and Settings. Feed is still a placeholder.
struct MainTabView: View {
    let profile: UserProfile

    @Environment(\.appEnvironment) private var environment

    var body: some View {
        TabView {
            Tab("Map", systemImage: "map") {
                CampusMapView(location: environment.location)
            }
            Tab("Feed", systemImage: "list.bullet") {
                placeholder(
                    systemImage: "list.bullet",
                    title: "Feed",
                    message: "A list of active posts will show up here."
                )
            }
            Tab("Settings", systemImage: "gearshape") {
                SettingsView(profile: profile)
            }
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

#Preview {
    MainTabView(profile: SampleData.profile)
        .environment(AuthViewModel(auth: MockAuthService(), initialState: .signedIn(SampleData.profile)))
        .environment(\.appEnvironment, .mock)
}
