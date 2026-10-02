import Foundation
import Testing
@testable import GatorPlate

@MainActor
struct AnalysisViewModelTests {
    private func model(
        _ scenario: MockFoodAnalyzer.Scenario, delay: Duration = .zero,
        statusInterval: Duration = .milliseconds(20), slowThreshold: Duration = .seconds(10)
    ) -> AnalysisViewModel {
        AnalysisViewModel(
            analyzer: MockFoodAnalyzer(scenario: scenario, delay: delay), jpeg: Data([1]),
            statusInterval: statusInterval, slowThreshold: slowThreshold
        )
    }

    @Test func startsIdle() {
        #expect(model(.success).state == .idle)
    }

    @Test func successMovesToSuccess() async {
        let vm = model(.success)
        vm.start()
        #expect(vm.state == .analyzing(statusIndex: 0))
        #expect(await waitUntil { vm.state == .success(SampleData.analysis) })
    }

    @Test func rejectionMovesToRejected() async {
        let vm = model(.rejected(.containsPeople))
        vm.start()
        #expect(await waitUntil { vm.state == .rejected(.containsPeople) })
    }

    @Test func failureMovesToFailed() async {
        let vm = model(.failure(.network))
        vm.start()
        #expect(await waitUntil { vm.state == .failed(.network) })
    }

    @Test func cancelReturnsToIdleAndNoLateResultAppears() async {
        let vm = model(.success, delay: .milliseconds(100))
        vm.start()
        vm.cancel()
        #expect(vm.state == .idle)
        try? await Task.sleep(for: .milliseconds(300))
        #expect(vm.state == .idle)
    }

    @Test func startWhileAnalyzingDoesNothing() async {
        let vm = model(.success, delay: .milliseconds(100))
        vm.start()
        vm.start()
        #expect(vm.state == .analyzing(statusIndex: 0))
        #expect(await waitUntil { vm.state == .success(SampleData.analysis) })
    }

    @Test func retryAfterFailureRunsAgain() async {
        let vm = model(.failure(.aiBusy))
        vm.start()
        #expect(await waitUntil { vm.state == .failed(.aiBusy) })
        vm.retry()
        #expect(vm.state == .analyzing(statusIndex: 0))
        #expect(await waitUntil { vm.state == .failed(.aiBusy) })
    }

    @Test func statusMessagesRotateWhileAnalyzing() async {
        let vm = model(.success, delay: .seconds(5))
        vm.start()
        #expect(vm.statusMessage == AnalysisViewModel.statusMessages[0])
        #expect(await waitUntil {
            if case .analyzing(let index) = vm.state { return index >= 1 }
            return false
        })
        guard case .analyzing(let index) = vm.state else { Issue.record("expected analyzing"); return }
        #expect(vm.statusMessage == AnalysisViewModel.statusMessages[index % AnalysisViewModel.statusMessages.count])
        vm.cancel()
    }

    @Test func slowAnalysesAreFlagged() async {
        let vm = model(.success, delay: .seconds(5), statusInterval: .milliseconds(10), slowThreshold: .milliseconds(30))
        vm.start()
        #expect(await waitUntil { vm.isTakingLong })
        vm.cancel()
        #expect(!vm.isTakingLong)
    }

    @Test func friendlyCopyNeverExposesInternals() {
        for error in [AppError.network, .aiBusy, .aiTimeout, .aiUnavailable, .unknown] {
            let message = error.analysisMessage
            #expect(message.contains("yourself"))
            #expect(!message.lowercased().contains("http"))
        }
    }
}
