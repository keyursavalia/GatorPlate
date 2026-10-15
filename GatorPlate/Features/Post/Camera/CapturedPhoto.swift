import UIKit

/// A photo ready for the post: downscaled, upright, metadata-free JPEG plus an in-memory preview.
/// Lives with the camera wrapper because it carries a `UIImage`.
nonisolated struct CapturedPhoto: Identifiable, Hashable, Sendable {
    enum Source: Sendable {
        case camera
        case library
    }

    let id = UUID()
    /// EXIF/GPS stripped, long edge <= `AppConfig.aiMaxImageLongEdge`.
    let jpegData: Data
    let previewImage: UIImage
    let pixelWidth: Int
    let pixelHeight: Int
    let source: Source

    static func == (lhs: CapturedPhoto, rhs: CapturedPhoto) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
