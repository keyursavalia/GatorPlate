import CoreGraphics
import Foundation
import ImageIO

/// Decodes a stored post photo into a bitmap sized for the screen, off the main thread (ImageIO thumbnailing,
/// so the full-size bitmap is never decoded). Orientation was baked in when the photo was captured.
nonisolated enum PhotoDecoder {
    @concurrent
    static func cgImage(from data: Data, maxPixel: Int = AppConfig.postPhotoMaxPixel) async -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}
