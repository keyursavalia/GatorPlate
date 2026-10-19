import Foundation

/// Turns raw model JSON into a trusted `FoodAnalysisOutcome` (AI spec section 3, rules 1-7).
/// Pure functions: no I/O, no logging, never throws, never trusts the model.
nonisolated enum FoodAnalysisSanitizer {
    // MARK: Decoding

    /// Lenient decode. Returns nil only when the text holds no JSON object at all.
    static func decode(_ text: String) -> RawFoodAnalysis? {
        // The MIME type should prevent code fences, but tolerate them (and any stray text) anyway.
        guard let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}"), start < end else { return nil }
        let json = Data(text[start...end].utf8)
        return try? JSONDecoder().decode(RawFoodAnalysis.self, from: json)
    }

    // MARK: Sanitizing

    static func sanitize(_ raw: RawFoodAnalysis, photoCount: Int = 1, promptVersion: String,
                         modelName: String) -> FoodAnalysisOutcome {
        // Rules 1-2, per photo. People first: privacy beats everything else.
        let gate = FoodAnalysisPhotoGate.evaluate(raw, photoCount: photoCount)
        if let rejection = gate.rejection { return .rejected(rejection) }
        guard let confidence = raw.confidence, confidence >= AppConfig.aiMinConfidence else {
            return .rejected(.lowConfidence)
        }

        let items = sanitizedItems(raw.items)
        let result = FoodAnalysisResult(
            title: sanitizedTitle(raw.title, items: items),
            description: sanitizedDescription(raw.description, items: items),
            items: items,
            overallDietary: overallDietary(for: items),
            allergens: sanitizedAllergens(raw.allergens),
            cautions: sanitizedCautions(raw.cautions),
            estimatedServings: raw.estimatedServings.flatMap { AppConfig.aiServingsRange.contains($0) ? $0 : nil },
            confidence: min(confidence, 1),
            promptVersion: promptVersion,
            modelName: modelName,
            keptPhotoIndices: gate.kept,
            removedForPeople: gate.removedForPeople,
            removedNotFood: gate.removedNotFood)
        return .accepted(result)
    }

    /// Rule 5: local logic is authoritative over the model's `overallDietary`.
    static func overallDietary(for items: [FoodItem]) -> DietaryClass {
        let classes = items.map(\.dietary)
        guard !classes.isEmpty, !classes.contains(.unknown) else { return .unknown }
        if classes.allSatisfy({ $0 == .vegan }) { return .vegan }
        if classes.allSatisfy({ $0 == .vegan || $0 == .vegetarian }) { return .vegetarian }
        if classes.allSatisfy({ $0 == .nonVegetarian }) { return .nonVegetarian }
        return .mixed
    }

    /// Rule 4 for diets. Item-level "mixed" makes no sense, so it becomes unknown too.
    static func dietary(from raw: String?) -> DietaryClass {
        switch normalizedToken(raw) {
        case "vegan": .vegan
        case "vegetarian": .vegetarian
        case "non_vegetarian", "nonvegetarian", "non_veg", "nonveg", "meat": .nonVegetarian
        default: .unknown
        }
    }

    /// The model's overall value, only for comparing against the local result.
    static func dietary(fromOverall raw: String?) -> DietaryClass {
        normalizedToken(raw) == "mixed" ? .mixed : dietary(from: raw)
    }

    /// Rule 4 for allergens: unknown values are dropped.
    static func allergen(from raw: String) -> Allergen? {
        switch normalizedToken(raw) {
        case "milk", "dairy": .milk
        case "eggs", "egg": .eggs
        case "fish": .fish
        case "shellfish", "crustaceans", "crustacean": .shellfish
        case "tree_nuts", "tree_nut", "treenuts", "nuts": .treeNuts
        case "peanuts", "peanut": .peanuts
        case "wheat", "gluten": .wheat
        case "soy", "soya", "soybeans": .soy
        case "sesame": .sesame
        default: nil
        }
    }

    // MARK: Fields

    /// Rule 3: non-empty, capped names, case-insensitive dedupe, at most `aiMaxItems`; calories only when plausible.
    private static func sanitizedItems(_ rawItems: [RawFoodAnalysis.Item]) -> [FoodItem] {
        var seen = Set<String>()
        var items: [FoodItem] = []
        for rawItem in rawItems where items.count < AppConfig.aiMaxItems {
            let name = truncated(cleanText(rawItem.name), to: AppConfig.aiItemNameMaxLength)
            guard !name.isEmpty, seen.insert(name.lowercased()).inserted else { continue }
            items.append(FoodItem(name: name, dietary: dietary(from: rawItem.dietary),
                                  calories: calories(low: rawItem.caloriesLow, high: rawItem.caloriesHigh)))
        }
        return items
    }

    /// Kept only when `0 < low <= high <= aiMaxCalories`; never swapped or guessed.
    private static func calories(low: Int?, high: Int?) -> CalorieRange? {
        guard let low, let high, low > 0, low <= high, high <= AppConfig.aiMaxCalories else { return nil }
        return CalorieRange(low: low, high: high)
    }

    private static func sanitizedAllergens(_ raw: [String]) -> [Allergen] {
        let found = Set(raw.compactMap(allergen(from:)))
        return Allergen.allCases.filter(found.contains)
    }

    private static func sanitizedCautions(_ raw: [String]) -> [String] {
        var seen = Set<String>()
        return raw
            .map { truncated(cleanText($0), to: AppConfig.aiCautionMaxLength) }
            .filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }
            .prefix(AppConfig.aiMaxCautions)
            .map { $0 }
    }

    /// Rule 7: no "FREE" prefix (everything on GatorPlate is free; S09), at most `aiTitleMaxLength`, built from
    /// the items when empty.
    private static func sanitizedTitle(_ raw: String?, items: [FoodItem]) -> String {
        var body = strippingFreePrefix(cleanText(raw))
        if body.isEmpty { body = items.first?.name ?? "Food" }
        return truncated(body, to: AppConfig.aiTitleMaxLength)
    }

    /// Drops a leading "FREE:", "Free -", "FREE!" and the like (older prompts and the model's habits).
    static func strippingFreePrefix(_ text: String) -> String {
        guard let match = text.prefixMatch(of: #/(?i)^free\b\s*[:!\-–—]*\s*/#) else { return text }
        return String(text[match.range.upperBound...])
    }

    /// Target 100-150 characters: longer text is cut at a word boundary; shorter text is kept as is.
    private static func sanitizedDescription(_ raw: String?, items: [FoodItem]) -> String {
        var text = cleanText(raw)
        if text.isEmpty, !items.isEmpty {
            text = items.map(\.name).formatted(.list(type: .and)) + "."
        }
        guard text.count > AppConfig.aiDescriptionMaxLength else { return text }
        return truncated(text, to: AppConfig.aiDescriptionMaxLength - 1) + "."
    }

    // MARK: Text hygiene

    /// Trims, collapses whitespace, and removes control characters, emoji, emails, URLs and phone numbers.
    static func cleanText(_ raw: String?) -> String {
        guard let raw else { return "" }
        let scalars = raw.unicodeScalars.compactMap { scalar -> Unicode.Scalar? in
            if CharacterSet.controlCharacters.contains(scalar) || CharacterSet.newlines.contains(scalar) { return " " }
            if isEmoji(scalar) { return nil }
            return scalar
        }
        var text = String(String.UnicodeScalarView(scalars))
        text.replace(#/[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}/#, with: "")
        text.replace(#/(?i)(https?:\/\/|www\.)\S+/#, with: "")
        text = removingPhoneNumbers(text)
        return text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    private static func isEmoji(_ scalar: Unicode.Scalar) -> Bool {
        // ZWJ and variation selectors glue emoji sequences together.
        if scalar.value == 0x200D || (0xFE00...0xFE0F).contains(scalar.value) { return true }
        // Plain digits, # and * also report `isEmoji`; only drop non-ASCII emoji.
        return scalar.properties.isEmoji && scalar.value > 0x7F
    }

    /// Removes digit runs that look like phone numbers (10+ digits), leaving ranges like "380-520" alone.
    private static func removingPhoneNumbers(_ text: String) -> String {
        text.replacing(#/\+?\(?\d[\d\-\s().]{8,}\d/#) { match in
            match.output.filter(\.isNumber).count >= 10 ? "" : match.output
        }
    }

    /// Cuts at the last word boundary at or before `limit` and drops dangling punctuation.
    static func truncated(_ text: String, to limit: Int) -> String {
        guard text.count > limit else { return text }
        let prefix = text.prefix(limit)
        let cut = prefix.lastIndex(of: " ").map { prefix[..<$0] } ?? prefix
        return String(cut).trimmingCharacters(in: .whitespaces.union(.punctuationCharacters))
    }

    private static func normalizedToken(_ raw: String?) -> String {
        (raw ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacing(" ", with: "_")
            .replacing("-", with: "_")
    }
}
