import Foundation

/// The app's Remote Config settings. Implementations are `@Observable`: views and models that read `current` update
/// when the owner publishes a change (realtime) without a relaunch.
@MainActor
protocol RuntimeConfigProviding: AnyObject {
    /// Always usable: the in-app defaults until cached or fetched values arrive.
    var current: RuntimeConfig { get }

    /// Applies cached values at once, then fetches and listens for updates in the background. Never blocks launch.
    func start()
}
