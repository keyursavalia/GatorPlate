import CoreGraphics
import Foundation
import ImageIO
import OSLog

/// In-memory post photos for the map card and the feed. Loads each photo once, even when asked twice at once.
@MainActor
final class PostImageCache {
    private let store: any ImageStore
    private let limit: Int
    private var images: [String: CGImage] = [:]
    private var order: [String] = []
    private var inFlight: [String: Task<CGImage?, Never>] = [:]

    init(store: any ImageStore, limit: Int = AppConfig.postImageCacheLimit) {
        self.store = store
        self.limit = limit
    }

    func cachedImage(for postId: String) -> CGImage? {
        images[postId]
    }

    /// Nil when there is no photo or it couldn't load; the caller shows a placeholder.
    func image(for postId: String) async -> CGImage? {
        if let image = images[postId] { return image }
        if let task = inFlight[postId] { return await task.value }
        let store = store
        let task = Task<CGImage?, Never> {
            do {
                guard let data = try await store.load(forPostId: postId) else { return nil }
                return Self.decode(data)
            } catch {
                Logger.services.error("Post photo load failed")
                return nil
            }
        }
        inFlight[postId] = task
        let image = await task.value
        inFlight[postId] = nil
        if let image { insert(image, for: postId) }
        return image
    }

    private func insert(_ image: CGImage, for postId: String) {
        if images[postId] == nil { order.append(postId) }
        images[postId] = image
        while order.count > limit {
            images[order.removeFirst()] = nil
        }
    }

    private nonisolated static func decode(_ data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: AppConfig.postImageMaxLongEdge,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}
