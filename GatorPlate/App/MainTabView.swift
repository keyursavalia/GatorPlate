import SwiftUI

/// Post-auth placeholder. Real Map and Feed arrive in Sprints 02 and 06.
struct MainTabView: View {
    let profile: UserProfile
    let onSignOut: () -> Void

    var body: some View {
        TabView {
            Tab("Map", systemImage: "map") {
                EmptyState(icon: "map", title: "Campus map", message: "Free food on campus will show up here.")
            }
            Tab("Feed", systemImage: "list.bullet") {
                EmptyState(icon: "list.bullet", title: "Feed", message: "A list of active posts will show up here.")
            }
            Tab("Settings", systemImage: "gearshape") {
                SettingsView(profile: profile, onSignOut: onSignOut)
            }
        }
    }
}
