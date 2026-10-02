import Observation

/// Tab and post selection shared by the Map and Feed tabs. Sprint 7 notifications call `selectPost(id:)`.
@MainActor
@Observable
final class NavigationModel {
    enum AppTab: Hashable { case map, feed, settings }

    var tab: AppTab = .map
    var selectedPostID: String?

    /// Shows the post's card on the Map tab. The id may not have arrived yet; `reconcile` drops it if it never does.
    func selectPost(id: String) {
        tab = .map
        selectedPostID = id
    }

    /// Clears a selection that points at a post that is gone, once the first snapshot has arrived.
    func reconcile(activePostIDs: Set<String>, hasLoaded: Bool) {
        guard hasLoaded, let selectedPostID, !activePostIDs.contains(selectedPostID) else { return }
        self.selectedPostID = nil
    }
}
