import CoreGraphics
import Foundation
import ImageIO
import OSLog

/// In-memory post photos for the map sheet, the feed and the viewer. Keyed by `"\(postId)#\(slot)"`.
/// Loads each photo once, even when asked twice at once.
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

    static func key(postId: String, slot: Int) -> String {
        "\(postId)#\(slot)"
    }

    func cachedImage(for postId: String, slot: Int) -> CGImage? {
        images[Self.key(postId: postId, slot: slot)]
    }

    /// Nil when there is no photo or it couldn't load; the caller shows a placeholder.
    func image(for postId: String, slot: Int) async -> CGImage? {
        let key = Self.key(postId: postId, slot: slot)
        if let image = images[key] { return image }
        if let task = inFlight[key] { return await task.value }
        let store = store
        let task = Task<CGImage?, Never> {
            do {
                guard let data = try await store.load(forPostId: postId, slot: slot) else { return nil }
                return Self.decode(data)
            } catch {
                Logger.services.error("Post photo load failed")
                return nil
            }
        }
        inFlight[key] = task
        let image = await task.value
        inFlight[key] = nil
        if let image { insert(image, for: key) }
        return image
    }

    private func insert(_ image: CGImage, for key: String) {
        if images[key] == nil { order.append(key) }
        images[key] = image
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
