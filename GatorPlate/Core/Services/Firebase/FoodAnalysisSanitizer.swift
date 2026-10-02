import Foundation

/// Turns untrusted model output into a validated outcome. Pure functions, no network.
/// Implements rules 1 to 7 of `docs/04-AI-GEMINI-SPEC.md` section 3. Local logic always wins over the model.
nonisolated enum FoodAnalysisSanitizer {
    static let maxTitleLength = 80
    static let maxDescriptionLength = 150
    static let maxItems = 8
    static let maxCautions = 4
    static let maxCalories = 3000
    static let titlePrefix = "FREE: "

    static func sanitize(_ raw: RawFoodAnalysis) -> FoodAnalysisOutcome {
        // Rule 2 first: a photo with people is never used, even if the model also says it is food.
        if raw.containsPeople == true { return .rejected(.containsPeople) }
        // Rule 1.
        if raw.isFood != true { return .rejected(.notFood) }
        guard let confidence = raw.confidence, confidence >= AppConfig.aiMinConfidence else {
            return .rejected(.lowConfidence)
        }

        let items = sanitizedItems(raw.items ?? [])
        guard !items.isEmpty else { return .rejected(.lowConfidence) }

        let allergens = sanitizedAllergens(raw.allergens ?? [])
        let cautions = Array(
            (raw.cautions ?? []).map(cleanText).filter { !$0.isEmpty }.prefix(maxCautions)
        )

        return .accepted(
            FoodAnalysisResult(
                title: sanitizedTitle(raw.title, firstItem: items[0].name),
                description: sanitizedDescription(raw.description, items: items),
                items: items,
                overallDietary: overallDietary(for: items.map(\.dietary)),
                allergenWarnings: allergens,
                cautions: cautions,
                estimatedServings: raw.estimatedServings.flatMap { (1...500).contains($0) ? $0 : nil },
                allergensUnverified: allergens.isEmpty
            )
        )
    }

    /// Rule 5. Anything unknown makes the whole dish unknown, so we never imply a safer class than we know.
    static func overallDietary(for classes: [DietaryClass]) -> DietaryClass {
        guard !classes.isEmpty, !classes.contains(.unknown) else { return .unknown }
        if classes.allSatisfy({ $0 == .vegan }) { return .vegan }
        if classes.allSatisfy({ $0 == .vegan || $0 == .vegetarian }) { return .vegetarian }
        if classes.allSatisfy({ $0 == .nonVegetarian }) { return .nonVegetarian }
        return .mixed
    }

    // MARK: Items, allergens

    static func sanitizedItems(_ raw: [RawFoodAnalysis.Item]) -> [FoodItem] {
        raw.compactMap { item -> FoodItem? in
            let name = cleanText(item.name ?? "")
            guard !name.isEmpty else { return nil }
            return FoodItem(
                name: truncated(name, to: 60),
                dietary: DietaryClass(itemSchemaValue: item.dietary),
                calories: calories(low: item.caloriesLow, high: item.caloriesHigh)
            )
        }
        .prefix(maxItems)
        .map { $0 }
    }

    /// Rule 3: `0 < low <= high <= 3000`, otherwise the estimate is dropped.
    static func calories(low: Int?, high: Int?) -> CalorieRange? {
        guard let low, let high, low > 0, low <= high, high <= maxCalories else { return nil }
        return CalorieRange(low: low, high: high)
    }

    /// Unknown values are ignored, duplicates removed, order is the canonical `Allergen` order.
    static func sanitizedAllergens(_ raw: [String]) -> [Allergen] {
        let found = Set(raw.compactMap { Allergen(schemaValue: $0) })
        return Allergen.allCases.filter(found.contains)
    }

    // MARK: Text

    /// Rule 7: always starts with `FREE: `; the app (not the AI) appends location and time later.
    static func sanitizedTitle(_ raw: String?, firstItem: String) -> String {
        var body = cleanText(raw ?? "")
        if let range = body.range(of: #"^free\s*:\s*"#, options: [.regularExpression, .caseInsensitive]) {
            body.removeSubrange(range)
        }
        if body.isEmpty { body = firstItem }
        return titlePrefix + truncated(body, to: maxTitleLength - titlePrefix.count)
    }

    /// Rule 3: trimmed at a word boundary to 150 characters. Empty descriptions are built from the items.
    static func sanitizedDescription(_ raw: String?, items: [FoodItem]) -> String {
        var text = cleanText(raw ?? "")
        if text.isEmpty {
            text = "Includes " + items.prefix(4).map(\.name).joined(separator: ", ") + "."
        }
        return truncated(text, to: maxDescriptionLength)
    }

    /// Removes emoji and control characters, collapses whitespace.
    static func cleanText(_ text: String) -> String {
        let scalars = text.unicodeScalars.filter { scalar in
            if scalar == "\n" || scalar == "\t" { return true }
            if scalar.properties.generalCategory == .control { return false }
            if scalar.value == 0xFE0F || scalar.value == 0x200D { return false }
            if scalar.properties.isEmojiPresentation { return false }
            if scalar.properties.isEmoji && scalar.value > 0x2000 { return false }
            return true
        }
        return String(String.UnicodeScalarView(scalars))
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    /// Cuts at a word boundary when the cut would land mid-word and a space exists in the back half.
    static func truncated(_ text: String, to limit: Int) -> String {
        guard text.count > limit else { return text }
        let head = text.prefix(limit)
        let nextIsBoundary = text[head.endIndex].isWhitespace
        var cut = Substring(head)
        if !nextIsBoundary, let space = head.lastIndex(where: \.isWhitespace),
           head.distance(from: head.startIndex, to: space) >= limit / 2 {
            cut = head[head.startIndex..<space]
        }
        return String(cut).trimmingCharacters(in: CharacterSet(charactersIn: " ,;:-"))
    }
}
