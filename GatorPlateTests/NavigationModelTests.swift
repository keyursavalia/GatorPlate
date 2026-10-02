import Testing
@testable import GatorPlate

@MainActor
struct NavigationModelTests {
    @Test func startsOnTheMapWithNothingSelected() {
        let model = NavigationModel()
        #expect(model.tab == .map)
        #expect(model.selectedPostID == nil)
    }

    @Test func selectPostSwitchesToTheMapAndSelects() {
        let model = NavigationModel()
        model.tab = .feed
        model.selectPost(id: "a")
        #expect(model.tab == .map)
        #expect(model.selectedPostID == "a")
    }

    @Test func reconcileKeepsASelectionThatExists() {
        let model = NavigationModel()
        model.selectPost(id: "a")
        model.reconcile(activePostIDs: ["a", "b"], hasLoaded: true)
        #expect(model.selectedPostID == "a")
    }

    @Test func reconcileWaitsForTheFirstSnapshot() {
        let model = NavigationModel()
        model.selectPost(id: "a")
        model.reconcile(activePostIDs: [], hasLoaded: false)
        #expect(model.selectedPostID == "a")
    }

    @Test func reconcileDropsASelectionThatIsGone() {
        let model = NavigationModel()
        model.selectPost(id: "a")
        model.reconcile(activePostIDs: ["b"], hasLoaded: true)
        #expect(model.selectedPostID == nil)
    }
}
