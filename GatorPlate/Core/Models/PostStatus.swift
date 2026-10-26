import Foundation

nonisolated enum PostStatus: String, Codable, Equatable, Sendable {
    case active, gone, expired
}
