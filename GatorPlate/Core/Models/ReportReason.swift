import Foundation

/// Reasons offered on the Report sheet. The stored text is the label, plus the note for "Other".
nonisolated enum ReportReason: String, CaseIterable, Identifiable, Sendable {
    case notFood, unsafe, spam, other

    var id: Self { self }

    var label: String {
        switch self {
        case .notFood: "Not food"
        case .unsafe: "Unsafe"
        case .spam: "Spam"
        case .other: "Other"
        }
    }

    /// Text written to `reports.reason`. A note is kept only for "Other".
    func reportText(note: String) -> String {
        let note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard self == .other, !note.isEmpty else { return label }
        return "\(label): \(note)"
    }
}
