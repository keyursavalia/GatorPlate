import Foundation
import Observation

/// Settable runtime config for previews and the harness.
@MainActor
@Observable
final class MockRuntimeConfig: RuntimeConfigProviding {
    var current: RuntimeConfig
    private(set) var started = false

    init(_ current: RuntimeConfig = .defaults) {
        self.current = current
    }

    func start() {
        started = true
    }
}
