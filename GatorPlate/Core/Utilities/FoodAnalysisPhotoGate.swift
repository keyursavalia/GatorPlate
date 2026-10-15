import Foundation

/// Per-photo privacy and food gate (prompt v2). Photos showing people are dropped first (never uploaded or shown
/// again), then photos without food. All photos with people -> `.containsPeople`; no food left -> `.notFood`.
/// A photo the model didn't report on falls back to the top-level flags, conservatively (any people = people).
nonisolated enum FoodAnalysisPhotoGate {
    struct Verdict: Equatable, Sendable {
        /// Indices into the input photos (0-based, in order) that may be used.
        var kept: [Int]
        var removedForPeople: Int
        var removedNotFood: Int
        var rejection: FoodAnalysisRejection?
    }

    static func evaluate(_ raw: RawFoodAnalysis, photoCount: Int) -> Verdict {
        guard photoCount > 0 else {
            return Verdict(kept: [], removedForPeople: 0, removedNotFood: 0, rejection: .notFood)
        }
        var flags: [Int: RawFoodAnalysis.Photo] = [:]
        for photo in raw.photos {
            guard let index = photo.index, (1...photoCount).contains(index), flags[index - 1] == nil else { continue }
            flags[index - 1] = photo
        }

        var withoutPeople: [Int] = []
        for index in 0..<photoCount {
            let showsPeople = flags[index]?.containsPeople ?? (raw.containsPeople ?? false)
            if !showsPeople { withoutPeople.append(index) }
        }
        let removedForPeople = photoCount - withoutPeople.count
        guard !withoutPeople.isEmpty else {
            return Verdict(kept: [], removedForPeople: removedForPeople, removedNotFood: 0, rejection: .containsPeople)
        }

        let kept = withoutPeople.filter { index in
            flags[index]?.isFood ?? (raw.isFood == true)
        }
        let removedNotFood = withoutPeople.count - kept.count
        return Verdict(kept: kept, removedForPeople: removedForPeople, removedNotFood: removedNotFood,
                       rejection: kept.isEmpty ? .notFood : nil)
    }
}
