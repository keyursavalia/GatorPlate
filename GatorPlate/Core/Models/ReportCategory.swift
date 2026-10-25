import Foundation

/// What's wrong with a post, as offered on the Report sheet (in this order) and stored in `reports.category`. Unsafe
/// needs a written reason, which the `onReportCreated` function's AI check reads; a credible one removes the post at
/// once. The others remove it after 3 different accounts report it (unsafe reports the AI doesn't believe count toward
/// those 3). Offensive reports also alert the admins for human review within 24 hours.
nonisolated enum ReportCategory: String, CaseIterable, Identifiable, Sendable {
    case unsafe, offensive, misleading, trading

    var id: Self { self }

    var label: String {
        switch self {
        case .unsafe: "Unsafe to eat"
        case .offensive: "Offensive or inappropriate"
        case .misleading: "Spam or misleading"
        case .trading: "Selling or trading"
        }
    }

    var explainer: String {
        switch self {
        case .unsafe: "Spoiled, undercooked, contaminated or an allergen not listed."
        case .offensive: "Harassment, hate, sexual content, photos of people or threats."
        case .misleading: "Not food, not there, fake or wrong details."
        case .trading: "Asks for money, swaps or anything in return."
        }
    }

    var systemImage: String {
        switch self {
        case .unsafe: "exclamationmark.triangle.fill"
        case .offensive: "hand.raised.slash.fill"
        case .misleading: "eye.slash.fill"
        case .trading: "dollarsign.circle.fill"
        }
    }

    /// Unsafe reports must say why, so a mistaken tap can't remove a post.
    var requiresReason: Bool { self == .unsafe }
}
