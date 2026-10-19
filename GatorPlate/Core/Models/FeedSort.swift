import Foundation

/// Feed order. Objective facts about the post only, never anything about the student (R6).
nonisolated enum FeedSort: String, Codable, CaseIterable, Sendable {
    case newest, endingSoon, nearest

    var title: String {
        switch self {
        case .newest: "Newest"
        case .endingSoon: "Ending soon"
        case .nearest: "Nearest"
        }
    }
}
