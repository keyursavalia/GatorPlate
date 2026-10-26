import CoreGraphics
import Foundation
import ImageIO
import OSLog

/// In-memory post photos for the map sheet, the feed and the viewer. Keyed by `"\(postId)#\(slot)"`.
/// Loads each photo once, even when asked twice at once. Map pins use small square thumbnails made from the same
/// download, kept apart so a pin never holds a full-size photo.
@MainActor
final class PostImageCache {
    private let store: any ImageStore
    private let limit: Int
    private var images: [String: CGImage] = [:]
    private var order: [String] = []
    private var inFlight: [String: Task<CGImage?, Never>] = [:]
    private var thumbnails: [String: CGImage] = [:]
    private var thumbnailOrder: [String] = []

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

    func cachedThumbnail(for postId: String, slot: Int) -> CGImage? {
        thumbnails[Self.key(postId: postId, slot: slot)]
    }

    /// A square, center-cropped thumbnail `pixels` wide (map pins), made once from the cached photo.
    func thumbnail(for postId: String, slot: Int, pixels: Int = AppConfig.mapPinThumbnailPixels) async -> CGImage? {
        let key = Self.key(postId: postId, slot: slot)
        if let thumbnail = thumbnails[key] { return thumbnail }
        guard let image = await image(for: postId, slot: slot) else { return nil }
        let thumbnail = await Task.detached(priority: .utility) { Self.squareThumbnail(of: image, pixels: pixels) }.value
        guard let thumbnail else { return nil }
        if thumbnails[key] == nil { thumbnailOrder.append(key) }
        thumbnails[key] = thumbnail
        while thumbnailOrder.count > AppConfig.mapPinThumbnailCacheLimit {
            thumbnails[thumbnailOrder.removeFirst()] = nil
        }
        return thumbnail
    }

    private func insert(_ image: CGImage, for key: String) {
        if images[key] == nil { order.append(key) }
        images[key] = image
        while order.count > limit {
            images[order.removeFirst()] = nil
        }
    }

    /// Aspect-fill into a `pixels` x `pixels` square.
    nonisolated static func squareThumbnail(of image: CGImage, pixels: Int) -> CGImage? {
        let side = CGFloat(pixels)
        guard pixels > 0, image.width > 0, image.height > 0,
              let context = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        let scale = max(side / CGFloat(image.width), side / CGFloat(image.height))
        let width = CGFloat(image.width) * scale
        let height = CGFloat(image.height) * scale
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: (side - width) / 2, y: (side - height) / 2, width: width, height: height))
        return context.makeImage()
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
