import Foundation

nonisolated enum PostStatus: String, Codable, Sendable {
    case active, gone, expired
}
