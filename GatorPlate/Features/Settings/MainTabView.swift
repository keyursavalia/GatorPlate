import SwiftUI

/// Sprint 1 placeholder: tabs for Map, Feed and Settings. Real content arrives in later sprints.
struct MainTabView: View {
    let profile: UserProfile

    var body: some View {
        TabView {
            Tab("Map", systemImage: "map") {
                placeholder(
                    systemImage: "map",
                    title: "Campus map",
                    message: "Free food near you will show up here."
                )
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
