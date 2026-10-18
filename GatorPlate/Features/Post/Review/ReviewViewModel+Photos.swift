import Foundation

/// Photos, edit tracking and photo encoding for the Review composer.
extension ReviewViewModel {
    /// From Edit photos without re-running AI.
    func updatePhotos(_ newPhotos: [CapturedPhoto]) {
        photos = newPhotos
    }

    /// A re-draft keeps the user's place, time and attestation (AI never fills those).
    func carryOverWhereAndWhen(from previous: ReviewViewModel) {
        draft.location = previous.draft.location
        draft.locationDetail = previous.draft.locationDetail
        draft.durationMinutes = previous.draft.durationMinutes
        draft.safetyAttested = previous.draft.safetyAttested
        initialDraft = draft
    }

    /// True once the user changed anything since the draft appeared (the auto-title following along doesn't count).
    var hasUserEdits: Bool {
        var current = draft
        var initial = initialDraft
        if !current.titleIsCustom {
            current.title = ""
            initial.title = ""
        }
        return current != initial
    }

    static func removedNotice(_ result: FoodAnalysisResult) -> String? {
        var parts: [String] = []
        if result.removedForPeople > 0 {
            parts.append(result.removedForPeople == 1 ? "1 photo that showed people"
                                                      : "\(result.removedForPeople) photos that showed people")
        }
        if result.removedNotFood > 0 {
            parts.append(result.removedNotFood == 1 ? "1 photo without food"
                                                    : "\(result.removedNotFood) photos without food")
        }
        guard !parts.isEmpty else { return nil }
        return "We left out \(parts.joined(separator: " and "))."
    }


    /// Each photo re-encoded for storage (300 KB cap), in parallel, in tray order; cached across retries.
    func encodedPhotoData() async -> [Data?] {
        let missing = photos.filter { encodedPhotos[$0.id] == nil }
        let encoder = encoder
        let encoded = await withTaskGroup(of: (UUID, Data?).self) { group in
            for photo in missing {
                let jpeg = photo.jpegData
                group.addTask { (photo.id, await encoder.encode(jpeg)) }
            }
            var results: [UUID: Data?] = [:]
            for await (id, data) in group { results[id] = data }
            return results
        }
        encodedPhotos.merge(encoded) { _, new in new }
        return photos.map { encodedPhotos[$0.id] ?? nil }
    }
}

extension ReviewViewModel {
    /// The draft as students will see it, for Review's Preview (read-only detail sheet).
    var previewPost: FoodPost {
        let now = Date.now
        let location = draft.location
        let coordinate = location?.coordinate ?? SFSUCampus.homeCoordinate
        let detail = PostText.clean(draft.locationDetail)
        return FoodPost(
            id: "preview", authorUid: author.uid, authorName: author.displayName, orgName: author.orgName,
            title: PostText.clean(draft.title), description: PostText.clean(draft.description),
            items: draft.filledItems, overallDietary: draft.overallDietary,
            allergenWarnings: draft.orderedAllergens, cautions: draft.filledCautions,
            estimatedServings: draft.estimatedServings,
            buildingId: location?.building.id ?? "", locationName: location?.displayName ?? "Location not chosen",
            locationDetail: detail.isEmpty ? nil : detail,
            latitude: coordinate.latitude, longitude: coordinate.longitude,
            photoSlots: Array(photos.indices), aiGenerated: aiBaseline != nil, editedAfterAI: editedAfterAI,
            status: .active, createdAt: now, expiresAt: availableUntil(now: now), updatedAt: now)
    }
}
