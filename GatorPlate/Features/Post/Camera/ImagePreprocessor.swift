import ImageIO
import OSLog
import UIKit
import UniformTypeIdentifiers

/// Turns encoded photo data (camera, library) into a `CapturedPhoto`, off the main thread.
/// ImageIO decodes straight to the target size, so the full-resolution image never sits in memory.
nonisolated struct ImagePreprocessor: Sendable {
    var maxLongEdge = AppConfig.aiMaxImageLongEdge
    var jpegQuality = AppConfig.aiJPEGQuality

    static let unreadable = AppError.validation("That photo couldn't be read. Try another one.")

    @concurrent
    func process(_ data: Data, source: CapturedPhoto.Source) async throws(AppError) -> CapturedPhoto {
        let image = try downscaledImage(from: data)
        let jpegData = try encodeJPEG(image)
        return CapturedPhoto(jpegData: jpegData, previewImage: UIImage(cgImage: image),
                             pixelWidth: image.width, pixelHeight: image.height, source: source)
    }

    /// Re-encodes a stripped JPEG at this preprocessor's `maxLongEdge` (used to shrink 3+ photos for the AI request).
    @concurrent
    func downscaledJPEG(_ data: Data) async throws(AppError) -> Data {
        try encodeJPEG(try downscaledImage(from: data))
    }

    /// Long edge <= `maxLongEdge` (never upscales), with the EXIF orientation baked into the pixels.
    private func downscaledImage(from data: Data) throws(AppError) -> CGImage {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, sourceOptions) else {
            Logger.services.error("Image preprocessing: unreadable data")
            throw Self.unreadable
        }
        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxLongEdge,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, thumbnailOptions as CFDictionary) else {
            Logger.services.error("Image preprocessing: decode failed")
            throw Self.unreadable
        }
        return image
    }

    /// Only the compression quality is written: no source properties, so EXIF, GPS and TIFF metadata are dropped.
    private func encodeJPEG(_ image: CGImage) throws(AppError) -> Data {
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output as CFMutableData,
                                                                 UTType.jpeg.identifier as CFString, 1, nil) else {
            throw .unknown
        }
        let properties = [kCGImageDestinationLossyCompressionQuality: jpegQuality] as CFDictionary
        CGImageDestinationAddImage(destination, image, properties)
        guard CGImageDestinationFinalize(destination) else {
            Logger.services.error("Image preprocessing: JPEG encode failed")
            throw .unknown
        }
        return output as Data
    }
}
