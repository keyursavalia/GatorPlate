import Foundation

nonisolated extension ImagePreprocessor {
    /// Progressively smaller settings tried when a photo is over the storage cap.
    static let capSteps: [(longEdge: Int, quality: Double)] = [
        (1024, 0.7), (1024, 0.55), (800, 0.55), (800, 0.45), (640, 0.45), (512, 0.4)
    ]

    /// Returns JPEG data at or under `maxBytes`, re-encoding from `data` with smaller settings if needed.
    /// Nil if even the smallest setting is too big, in which case the post goes out without a photo.
    /// Output never carries GPS or other metadata (`process` encodes without properties).
    static func fittingCap(_ data: Data, maxBytes: Int = AppConfig.maxImageBytes) -> Data? {
        if data.count <= maxBytes, !ImageMetadata.hasGPS(data) { return data }
        for step in capSteps {
            guard let photo = try? process(data: data, maxLongEdge: step.longEdge, quality: step.quality) else {
                return nil
            }
            if photo.jpegData.count <= maxBytes { return photo.jpegData }
        }
        return nil
    }

    @concurrent
    static func fittingCapInBackground(_ data: Data, maxBytes: Int = AppConfig.maxImageBytes) async -> Data? {
        fittingCap(data, maxBytes: maxBytes)
    }
}
