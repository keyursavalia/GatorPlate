import Foundation

/// Polls until `condition` holds (or ~5 s pass). For tests that wait on async stream delivery.
@MainActor
func waitUntil(_ condition: @MainActor () -> Bool) async -> Bool {
    for _ in 0..<500 {
        if condition() { return true }
        try? await Task.sleep(for: .milliseconds(10))
    }
    return condition()
}
