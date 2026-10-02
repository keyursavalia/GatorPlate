import ImageIO
import UIKit
import UniformTypeIdentifiers

/// Turns whatever the camera or library produced into the upright, small, metadata-free JPEG the rest of
/// the app uses. ImageIO downsamples straight from the encoded data, so the full-size bitmap is never decoded.
nonisolated enum ImagePreprocessor {
    /// Runs off the main thread.
    @concurrent
    static func processInBackground(
        data: Data,
        maxLongEdge: Int = AppConfig.aiMaxImageLongEdge,
        quality: Double = AppConfig.aiJPEGQuality
    ) async throws -> CapturedPhoto {
        try process(data: data, maxLongEdge: maxLongEdge, quality: quality)
    }

    static func process(
        data: Data,
        maxLongEdge: Int = AppConfig.aiMaxImageLongEdge,
        quality: Double = AppConfig.aiJPEGQuality
    ) throws -> CapturedPhoto {
        guard maxLongEdge > 0,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(source) > 0,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              width > 0, height > 0
        else { throw CameraError.invalidImage }

        // Never upscale: the thumbnail API would otherwise grow small images to the maximum.
        let targetLongEdge = min(maxLongEdge, max(width, height))
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            // Bakes the EXIF orientation into the pixels so the output is upright with no orientation tag.
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: targetLongEdge
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw CameraError.invalidImage
        }

        let jpeg = try encodeJPEG(image, quality: quality)
        return CapturedPhoto(previewImage: UIImage(cgImage: image), jpegData: jpeg)
    }

    /// Encodes without passing any properties, so no EXIF, GPS or TIFF metadata is written.
    static func encodeJPEG(_ image: CGImage, quality: Double) throws -> Data {
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output, UTType.jpeg.identifier as CFString, 1, nil
        ) else { throw CameraError.invalidImage }
        let options = [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary
        CGImageDestinationAddImage(destination, image, options)
        guard CGImageDestinationFinalize(destination) else { throw CameraError.invalidImage }
        return output as Data
    }
}
