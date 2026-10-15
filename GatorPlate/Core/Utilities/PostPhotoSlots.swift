import Foundation

/// Which photo slots a post has. Slot 0 is the cover at `postImages/{postId}.jpg`; slots 1-3 are
/// `postImages/{postId}_{slot}.jpg`. Posts from before Sprint 08 have no `photoSlots`, only `hasPhoto`.
nonisolated enum PostPhotoSlots {
    static let all = 0..<AppConfig.postMaxPhotos

    /// Ascending, unique, valid slots from a Firestore value; an old post with `hasPhoto == true` reads as `[0]`.
    static func decode(_ raw: Any?, hasPhoto: Bool?) -> [Int] {
        guard let values = raw as? [Any] else { return hasPhoto == true ? [0] : [] }
        let slots = Set(values.compactMap { $0 as? Int }.filter(all.contains))
        return Array(slots).sorted()
    }

    /// Storage object name for a slot.
    static func objectName(postId: String, slot: Int) -> String {
        slot == 0 ? "\(postId).jpg" : "\(postId)_\(slot).jpg"
    }
}
