import FirebaseCore
import SwiftUI

/// Placeholder root. Replaced by auth/tab navigation in Sprint 01.
struct RootView: View {
    private var isFirebaseConfigured: Bool { FirebaseApp.app() != nil }

    var body: some View {
        EmptyState(
            icon: isFirebaseConfigured ? "checkmark.seal.fill" : "exclamationmark.triangle.fill",
            title: AppConfig.appName,
            message: isFirebaseConfigured ? "Firebase is configured." : "Firebase is not configured."
        )
    }
}

#Preview {
    RootView()
}
