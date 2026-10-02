import SwiftUI

/// App root: hands the auth service to `AuthGate`, which owns session state and routing.
struct RootView: View {
    @Environment(\.appEnvironment) private var environment

    var body: some View {
        AuthGate(auth: environment.auth)
    }
}

#Preview {
    RootView().environment(\.appEnvironment, .mock)
}
