import Foundation
import ImageIO
import OSLog
import UniformTypeIdentifiers

/// Re-encodes the analysis JPEG for storage: `postImageMaxLongEdge` at `postImageJPEGQuality`, stepping
/// quality and then size down until it fits `postImageMaxBytes`. Output carries no metadata.
nonisolated struct PostImageEncoder: Sendable {
    /// Nil when the image can't be decoded or never fits the cap; the post then publishes without a photo.
    @concurrent
    func encode(_ jpeg: Data) async -> Data? {
        let attempts: [(longEdge: Int, quality: Double)] =
            ([AppConfig.postImageJPEGQuality] + AppConfig.postImageFallbackQualities).map { (AppConfig.postImageMaxLongEdge, $0) }
            + AppConfig.postImageFallbackQualities.map { (AppConfig.postImageFallbackLongEdge, $0) }
        for attempt in attempts {
            guard let image = downscaled(jpeg, maxLongEdge: attempt.longEdge),
                  let data = encoded(image, quality: attempt.quality) else { return nil }
            if data.count <= AppConfig.postImageMaxBytes { return data }
        }
        Logger.services.error("Post image over the size cap after all attempts")
        return nil
    }

    private func downscaled(_ data: Data, maxLongEdge: Int) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary) else {
            Logger.services.error("Post image: unreadable data")
            return nil
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxLongEdge,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    /// Only the compression quality is written, so no EXIF/GPS is carried over.
    private func encoded(_ image: CGImage, quality: Double) -> Data? {
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output as CFMutableData,
                                                                 UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }
}
