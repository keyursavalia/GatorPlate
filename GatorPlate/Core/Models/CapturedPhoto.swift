import UIKit

/// A photo ready for the next step: upright, downscaled, metadata stripped.
nonisolated struct CapturedPhoto: Sendable, Equatable {
    let previewImage: UIImage
    let jpegData: Data

    var byteCount: Int { jpegData.count }

    /// Pixel size (the preview image is built at scale 1).
    var pixelSize: CGSize { previewImage.size }

    static func == (lhs: CapturedPhoto, rhs: CapturedPhoto) -> Bool {
        lhs.jpegData == rhs.jpegData
    }
}
