import SwiftUI

/// One report: the post as reported, the reason, the AI verdict, the poster's record, and the actions: Remove post
/// or Dismiss while it needs review, Remove post after a dismissal, none once removed. Follows the live report, and
/// goes back to the list after an action succeeds (the report moves to Handled there).
struct AdminReportDetailView: View {
    let viewModel: AdminViewModel

    @State private var moderation: AdminModeration?
    @State private var isConfirmingRemoval = false
    @State private var isConfirmingDismissal = false
    @State private var withStrike = true
    @Environment(\.dismiss) private var dismiss

    private let initialReport: AdminReport
    private var report: AdminReport { viewModel.report(id: initialReport.id) ?? initialReport }

    init(report: AdminReport, viewModel: AdminViewModel) {
        initialReport = report
        self.viewModel = viewModel
    }

    var body: some View {
        List {
            if let outcome = report.outcomeLabel {
                Section {
                    LabeledContent("Outcome", value: outcome)
                    if let resolvedAt = report.resolvedAt {
                        LabeledContent("Closed", value: resolvedAt.formatted(date: .abbreviated, time: .shortened))
                    }
                }
            }
            Section("Report") {
                LabeledContent("Category", value: report.category.label)
                LabeledContent("Reported", value: report.createdAt.formatted(date: .abbreviated, time: .shortened))
                if let reason = report.reason {
                    Text(reason).accessibilityLabel("Reason: \(reason)")
                }
                if let verdict = report.aiVerdict {
                    LabeledContent("AI check", value: verdict + (report.aiConcern.map { " · \($0)" } ?? ""))
                    if let rationale = report.aiRationale, !rationale.isEmpty {
                        Text(rationale).font(.subheadline).foregroundStyle(.secondary)
                    }
                }
            }
            if let snapshot = report.snapshot {
                Section("Post") {
                    Text(snapshot.title).font(.headline)
                    if !snapshot.description.isEmpty { Text(snapshot.description) }
                    LabeledContent("Place", value: snapshot.locationName)
                    LabeledContent("Poster", value: snapshot.posterName)
                }
            }
            if let moderation {
                Section("Poster's record") {
                    LabeledContent("Removals (30 days)", value: String(moderation.removals.count))
                    LabeledContent("Blocked by", value: String(moderation.blockedByCount))
                    if let until = moderation.bannedUntil, until > .now {
                        LabeledContent("Posting paused until",
                                       value: until.formatted(date: .abbreviated, time: .shortened))
                    }
                }
            }
            if report.resolution != .removed {
                Section {
                    Toggle("Count as a strike", isOn: $withStrike)
                    Button("Remove post", role: .destructive) { isConfirmingRemoval = true }
                        .disabled(viewModel.runningAction != nil)
                } footer: {
                    Text("Removes the post if it's still up and closes every report on it. A strike counts toward "
                         + "a posting pause. The poster gets an in-app notice, not a push.")
                }
            }
            if report.isOpen {
                Section {
                    Button("Dismiss reports") { isConfirmingDismissal = true }
                        .disabled(viewModel.runningAction != nil)
                } footer: {
                    Text("Keeps the post and closes every report on it. No strike, and nobody is told.")
                }
            }
        }
        .navigationTitle(report.category.label)
        .navigationBarTitleDisplayMode(.inline)
        .overlay { if viewModel.runningAction != nil { ProgressView().controlSize(.large) } }
        .task {
            guard let uid = report.snapshot?.authorUid, !uid.isEmpty else { return }
            moderation = try? await viewModel.service.moderation(uid: uid)
        }
        .alert("Remove this post?", isPresented: $isConfirmingRemoval) {
            Button("Remove", role: .destructive) { run(.removePost(postId: report.postId, strike: withStrike)) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(withStrike ? "It disappears for everyone and counts as a strike." : "It disappears for everyone.")
        }
        .alert("Dismiss the reports on this post?", isPresented: $isConfirmingDismissal) {
            Button("Dismiss") { run(.dismissReports(postId: report.postId)) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The post stays up. Its reports move to Handled.")
        }
    }
}

extension AdminReportDetailView {
    private func run(_ action: AdminActionRequest) {
        Task {
            if await viewModel.run(action) { dismiss() }
        }
    }
}

#Preview {
    NavigationStack {
        AdminReportDetailView(report: .sample, viewModel: AdminViewModel(service: MockAdminService()))
    }
}
