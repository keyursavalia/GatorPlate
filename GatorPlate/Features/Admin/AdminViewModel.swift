import Foundation
import Observation
import OSLog

/// Settings > Moderation: live appeals and reports, the poster's moderation record, and actions (each one an
/// `adminActions` doc processed by the function). Keeps the last lists on a listener error and shows a note.
@MainActor
@Observable
final class AdminViewModel {
    enum Tab: String, CaseIterable, Identifiable {
        case reports, appeals
        var id: Self { self }
        var title: String { self == .reports ? "Reports" : "Appeals" }
    }

    var tab = Tab.reports
    private(set) var appeals: [AdminAppeal] = []
    private(set) var reports: [AdminReport] = []
    private(set) var loadError: String?
    /// The action in flight, so its buttons show progress and others are disabled.
    private(set) var runningAction: AdminActionRequest?
    /// The last action's outcome, shown as an alert.
    var outcome: AdminActionOutcome?

    @ObservationIgnored let service: any AdminService
    @ObservationIgnored private var tasks: [Task<Void, Never>] = []

    init(service: any AdminService) {
        self.service = service
    }

    var openAppeals: [AdminAppeal] { appeals.filter(\.isOpen) }
    var decidedAppeals: [AdminAppeal] { appeals.filter { !$0.isOpen } }
    var sortedReports: [AdminReport] { reports.sorted(by: AdminReport.reviewOrder) }

    func start() {
        guard tasks.isEmpty else { return }
        tasks.append(Task { [weak self] in
            guard let stream = self?.service.observeAppeals() else { return }
            do {
                for try await list in stream { self?.appeals = list }
            } catch {
                self?.loadError = "Couldn't load appeals. Check that this account is still an admin."
            }
        })
        tasks.append(Task { [weak self] in
            guard let stream = self?.service.observeReports() else { return }
            do {
                for try await list in stream { self?.reports = list }
            } catch {
                self?.loadError = "Couldn't load reports. Check that this account is still an admin."
            }
        })
    }

    func stop() {
        tasks.forEach { $0.cancel() }
        tasks = []
    }

    func run(_ action: AdminActionRequest) async {
        guard runningAction == nil else { return }
        runningAction = action
        defer { runningAction = nil }
        do {
            outcome = try await service.run(action)
        } catch {
            outcome = AdminActionOutcome(succeeded: false, message: ((error as? AppError) ?? .unknown).userMessage)
        }
        Logger.ui.info("Admin action \(self.outcome?.succeeded == true ? "done" : "failed", privacy: .public)")
    }
}
