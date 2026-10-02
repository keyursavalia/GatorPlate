import Foundation

nonisolated protocol ImageStore: Sendable {
    func save(jpeg: Data, forPostID postID: String) async throws
    func load(forPostID postID: String) async throws -> Data?
}
