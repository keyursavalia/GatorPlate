import SwiftUI

/// Settings > Moderation (admins only): reports from the last 90 days (offensive and unchecked unsafe first) and
/// appeals (open first). Tapping one opens its detail with the actions.
struct AdminView: View {
    let viewModel: AdminViewModel

    var body: some View {
        @Bindable var viewModel = viewModel
        List {
            Section {
                Picker("Show", selection: $viewModel.tab) {
                    ForEach(AdminViewModel.Tab.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
            if let error = viewModel.loadError {
                Section { NoteRow(text: error, systemImage: "exclamationmark.triangle") }
            }
            switch viewModel.tab {
            case .reports: reports
            case .appeals: appeals
            }
        }
        .overlay { emptyState }
        .navigationTitle("Moderation")
        .navigationBarTitleDisplayMode(.inline)
        .task { viewModel.start() }
        .onDisappear { viewModel.stop() }
        .alert(viewModel.outcome?.succeeded == true ? "Done" : "Didn't work",
               isPresented: Binding(get: { viewModel.outcome != nil }, set: { if !$0 { viewModel.outcome = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.outcome?.message ?? "")
        }
    }

    /// Centered under the picker when the current tab has nothing.
    @ViewBuilder
    private var emptyState: some View {
        switch viewModel.tab {
        case .reports where viewModel.reports.isEmpty:
            EmptyState(icon: "checkmark.shield.fill", title: "All clear",
                       message: "No reports in the last 90 days. Offensive reports and unsafe reports the AI "
                           + "couldn't check will show up first.",
                       tint: Theme.Palette.success)
        case .appeals where viewModel.appeals.isEmpty:
            EmptyState(icon: "envelope.open.fill", title: "No appeals",
                       message: "When someone appeals a posting pause, it shows up here. Open appeals come first.")
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private var reports: some View {
        if !viewModel.reports.isEmpty {
            Section {
                ForEach(viewModel.sortedReports) { report in
                    NavigationLink {
                        AdminReportDetailView(report: report, viewModel: viewModel)
                    } label: {
                        let when = report.createdAt.formatted(.relative(presentation: .named))
                        ListRow(title: report.snapshot?.title ?? "Post \(report.postId.prefix(6))…",
                                systemImage: report.category.systemImage,
                                subtitle: "\(report.category.label) · \(when)",
                                iconTint: report.needsHuman ? Theme.Palette.danger : nil)
                    }
                }
            } footer: {
                Text("Offensive reports and unsafe reports the AI couldn't check come first. "
                     + "Respond to offensive reports within 24 hours.")
            }
        }
    }

    @ViewBuilder
    private var appeals: some View {
        if !viewModel.openAppeals.isEmpty {
            Section("Open") { ForEach(viewModel.openAppeals) { appealLink($0) } }
        }
        if !viewModel.decidedAppeals.isEmpty {
            Section("Decided") { ForEach(viewModel.decidedAppeals) { appealLink($0) } }
        }
    }

    private func appealLink(_ appeal: AdminAppeal) -> some View {
        NavigationLink {
            AdminAppealDetailView(appeal: appeal, viewModel: viewModel)
        } label: {
            ListRow(title: String(appeal.message.prefix(60)), systemImage: "envelope.open",
                    subtitle: appeal.resolution.map { $0 == .upheld ? "Upheld" : "Denied" }
                        ?? "Paused until \(appeal.bannedUntil.formatted(date: .abbreviated, time: .shortened))")
        }
    }
}

extension AdminReport {
    /// Shown in red: a person must look at it.
    var needsHuman: Bool {
        category == .offensive || (category == .unsafe && (aiVerdict == "unavailable" || aiVerdict == "disabled"))
    }
}

#Preview {
    NavigationStack {
        AdminView(viewModel: AdminViewModel(service: MockAdminService(appeals: [.sample], reports: [.sample])))
    }
}

#Preview("Empty") {
    NavigationStack {
        AdminView(viewModel: AdminViewModel(service: MockAdminService()))
    }
}

#Preview("AX5") {
    NavigationStack {
        AdminView(viewModel: AdminViewModel(service: MockAdminService(appeals: [.sample], reports: [.sample])))
    }
    .dynamicTypeSize(.accessibility5)
}
