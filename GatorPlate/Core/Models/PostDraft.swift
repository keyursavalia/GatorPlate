import Foundation

/// One food item in the Review form. The stable `id` keeps add, remove and rename safe in a `ForEach`.
nonisolated struct DraftItem: Identifiable, Hashable, Sendable {
    let id: UUID
    var name: String
    var dietary: DietaryClass
    var calories: CalorieRange?

    init(id: UUID = UUID(), name: String, dietary: DietaryClass = .unknown, calories: CalorieRange? = nil) {
        self.id = id
        self.name = name
        self.dietary = dietary
        self.calories = calories
    }

    init(_ item: FoodItem) {
        self.init(name: item.name, dietary: item.dietary, calories: item.calories)
    }
}

/// Where the food is: a catalog building, or a pin dropped inside the campus region.
nonisolated struct PostLocation: Equatable, Sendable {
    var buildingId: String
    var name: String
    var shortName: String
    var coordinate: Coordinate
}

/// Everything the poster can edit in the Review form. A plain value so it is easy to compare and test.
nonisolated struct PostDraft: Equatable, Sendable {
    var title = ""
    var description = ""
    var items: [DraftItem] = []
    var allergens: Set<Allergen> = []
    /// True when an AI draft reported no allergens: the post says "unverified", never "allergen free".
    var allergensUnverified = false
    var cautions: [String] = []
    var servings: Int?
    /// Catalog building id. Nil when the poster dropped a pin (or has not chosen yet).
    var buildingId: String?
    var pin: Coordinate?
    /// Room, floor or entrance. Required.
    var roomDetail = ""
    var durationMinutes = AppConfig.defaultPostDurationMinutes
    var attested = false

    init() {}

    /// Pre-fills from an accepted AI analysis.
    init(analysis: FoodAnalysisResult) {
        title = analysis.title
        description = analysis.description
        items = analysis.items.map(DraftItem.init)
        allergens = Set(analysis.allergenWarnings)
        allergensUnverified = analysis.allergensUnverified
        cautions = analysis.cautions
        servings = analysis.estimatedServings
    }

    // MARK: Derived

    /// Resolved from the building catalog or the pin. Nil if neither is set or the pin is off campus.
    var location: PostLocation? {
        if let buildingId, let building = CampusBuildings.building(id: buildingId) {
            return PostLocation(
                buildingId: building.id, name: building.name, shortName: building.shortName,
                coordinate: building.coordinate
            )
        }
        if buildingId == nil, let pin, SFSUCampus.contains(pin) {
            return PostLocation(
                buildingId: AppConfig.customPinBuildingId, name: AppConfig.customPinLocationName,
                shortName: AppConfig.customPinLocationName, coordinate: pin
            )
        }
        return nil
    }

    /// Always recomputed locally from the items, never taken from the model.
    var overallDietary: DietaryClass {
        FoodAnalysisSanitizer.overallDietary(for: cleanedItems.map(\.dietary))
    }

    func expiresAt(from now: Date) -> Date {
        now.addingTimeInterval(TimeInterval(durationMinutes * 60))
    }

    /// Items with names trimmed; blank rows dropped.
    var cleanedItems: [DraftItem] {
        items.compactMap { item in
            let name = PostText.line(item.name)
            guard !name.isEmpty else { return nil }
            var copy = item
            copy.name = name
            return copy
        }
    }

    // MARK: AI comparison

    /// The AI-owned fields in a normalized shape, so an untouched draft equals its baseline.
    struct AIFields: Equatable {
        var title: String
        var description: String
        var items: [String]
        var allergens: Set<Allergen>
        var cautions: [String]
        var servings: Int?
    }

    var aiFields: AIFields {
        AIFields(
            title: PostText.line(title),
            description: PostText.line(description),
            items: cleanedItems.map { "\($0.name)|\($0.dietary.rawValue)" },
            allergens: allergens,
            cautions: cautions.map(PostText.line).filter { !$0.isEmpty },
            servings: servings
        )
    }

    /// True when the poster changed any AI-filled field. Always false on the manual path (`baseline` nil).
    func editedAfterAI(comparedTo baseline: FoodAnalysisResult?) -> Bool {
        guard let baseline else { return false }
        return aiFields != PostDraft(analysis: baseline).aiFields
    }

    // MARK: Building the post

    /// The document to store. Only user-approved fields: the raw AI response is never kept.
    func makePost(
        id: String,
        author: UserProfile,
        now: Date,
        hasPhoto: Bool,
        aiGenerated: Bool,
        editedAfterAI: Bool
    ) -> FoodPost? {
        guard let location else { return nil }
        let expires = expiresAt(from: now)
        let detail = PostText.line(roomDetail)
        let cleanCautions = cautions.map(PostText.line).filter { !$0.isEmpty }
        return FoodPost(
            id: id,
            authorUid: author.uid,
            authorName: author.displayName,
            orgName: author.accountType == .organization ? author.orgName : nil,
            title: PostText.line(title),
            description: PostText.line(description),
            items: cleanedItems.map { FoodItem(name: $0.name, dietary: $0.dietary, calories: $0.calories) },
            overallDietary: overallDietary,
            allergenWarnings: Allergen.allCases.filter { allergens.contains($0) },
            cautions: cleanCautions,
            estimatedServings: servings,
            buildingId: location.buildingId,
            locationName: location.name,
            locationDetail: detail.isEmpty ? nil : detail,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            hasPhoto: hasPhoto,
            aiGenerated: aiGenerated,
            editedAfterAI: editedAfterAI,
            status: .active,
            createdAt: now,
            expiresAt: expires,
            updatedAt: now
        )
    }
}

/// Plain-text cleanup for user input. Posts are rendered as plain text, never as markdown or HTML.
nonisolated enum PostText {
    /// Control characters and line breaks become single spaces; runs of whitespace collapse; ends are trimmed.
    static func line(_ text: String) -> String {
        let mapped = text.unicodeScalars.map { scalar -> Character in
            CharacterSet.controlCharacters.contains(scalar) || CharacterSet.newlines.contains(scalar)
                ? " " : Character(scalar)
        }
        return String(mapped)
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }
}
