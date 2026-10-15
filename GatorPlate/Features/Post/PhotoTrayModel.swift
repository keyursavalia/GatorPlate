import Foundation
import Observation

/// The post's photos while it's being made: ordered, up to `AppConfig.postMaxPhotos`, camera and library mixed.
/// The first photo is the cover. Lives in memory only, like the rest of the draft.
@MainActor
@Observable
final class PhotoTrayModel {
    private(set) var photos: [CapturedPhoto] = []
    let capacity: Int

    init(capacity: Int = AppConfig.postMaxPhotos) {
        self.capacity = capacity
    }

    var remaining: Int { max(0, capacity - photos.count) }
    var isFull: Bool { photos.count >= capacity }
    var isEmpty: Bool { photos.isEmpty }
    var ids: [UUID] { photos.map(\.id) }

    /// False when the tray is full.
    @discardableResult
    func add(_ photo: CapturedPhoto) -> Bool {
        guard !isFull else { return false }
        photos.append(photo)
        return true
    }

    /// Adds in order up to the remaining room; returns how many were added.
    @discardableResult
    func add(contentsOf newPhotos: [CapturedPhoto]) -> Int {
        let accepted = Array(newPhotos.prefix(remaining))
        photos.append(contentsOf: accepted)
        return accepted.count
    }

    func remove(id: UUID) {
        photos.removeAll { $0.id == id }
    }

    func makeCover(id: UUID) {
        guard let index = photos.firstIndex(where: { $0.id == id }), index > 0 else { return }
        photos.insert(photos.remove(at: index), at: 0)
    }

    /// VoiceOver "Move left/right": -1 or +1.
    func move(id: UUID, by offset: Int) {
        guard let index = photos.firstIndex(where: { $0.id == id }) else { return }
        let target = index + offset
        guard photos.indices.contains(target) else { return }
        photos.swapAt(index, target)
    }

    /// Drag and drop: puts the photo where `targetId` is.
    func move(id: UUID, to targetId: UUID) {
        guard id != targetId,
              let from = photos.firstIndex(where: { $0.id == id }),
              let to = photos.firstIndex(where: { $0.id == targetId }) else { return }
        let photo = photos.remove(at: from)
        photos.insert(photo, at: to)
    }

    /// After the AI: only these photos stay (people and non-food photos are dropped for good).
    func keep(indices: [Int]) {
        let keep = Set(indices)
        photos = photos.enumerated().filter { keep.contains($0.offset) }.map(\.element)
    }

    func removeAll() {
        photos.removeAll()
    }
}
