import Foundation

/// What the model returned, decoded as loosely as possible. Every field is optional and a field of the
/// wrong type decodes to nil instead of failing the whole response. `FoodAnalysisSanitizer` validates it.
nonisolated struct RawFoodAnalysis: Decodable, Equatable, Sendable {
    struct Item: Decodable, Equatable, Sendable {
        var name: String?
        var dietary: String?
        var caloriesLow: Int?
        var caloriesHigh: Int?

        init(name: String? = nil, dietary: String? = nil, caloriesLow: Int? = nil, caloriesHigh: Int? = nil) {
            self.name = name
            self.dietary = dietary
            self.caloriesLow = caloriesLow
            self.caloriesHigh = caloriesHigh
        }

        enum CodingKeys: String, CodingKey { case name, dietary, caloriesLow, caloriesHigh }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            name = try? container.decodeIfPresent(String.self, forKey: .name)
            dietary = try? container.decodeIfPresent(String.self, forKey: .dietary)
            caloriesLow = Self.lenientInt(container, .caloriesLow)
            caloriesHigh = Self.lenientInt(container, .caloriesHigh)
        }

        private static func lenientInt(_ container: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> Int? {
            if let value = try? container.decodeIfPresent(Int.self, forKey: key) { return value }
            if let value = try? container.decodeIfPresent(Double.self, forKey: key), value.isFinite {
                return Int(value.rounded())
            }
            return nil
        }
    }

    var isFood: Bool?
    var containsPeople: Bool?
    var confidence: Double?
    var items: [Item]?
    var estimatedServings: Int?
    var allergens: [String]?
    var cautions: [String]?
    var title: String?
    var description: String?

    init(
        isFood: Bool? = nil, containsPeople: Bool? = nil, confidence: Double? = nil, items: [Item]? = nil,
        estimatedServings: Int? = nil, allergens: [String]? = nil, cautions: [String]? = nil,
        title: String? = nil, description: String? = nil
    ) {
        self.isFood = isFood
        self.containsPeople = containsPeople
        self.confidence = confidence
        self.items = items
        self.estimatedServings = estimatedServings
        self.allergens = allergens
        self.cautions = cautions
        self.title = title
        self.description = description
    }

    // `notes` is deliberately not decoded: it is debugging text from the model and is never shown or logged.
    enum CodingKeys: String, CodingKey {
        case isFood, containsPeople, confidence, items, estimatedServings, allergens, cautions, title, description
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isFood = try? container.decodeIfPresent(Bool.self, forKey: .isFood)
        containsPeople = try? container.decodeIfPresent(Bool.self, forKey: .containsPeople)
        confidence = try? container.decodeIfPresent(Double.self, forKey: .confidence)
        items = (try? container.decodeIfPresent([Lossy<Item>].self, forKey: .items))?.compactMap(\.value)
        if let value = try? container.decodeIfPresent(Int.self, forKey: .estimatedServings) {
            estimatedServings = value
        } else if let value = try? container.decodeIfPresent(Double.self, forKey: .estimatedServings), value.isFinite {
            estimatedServings = Int(value.rounded())
        }
        allergens = (try? container.decodeIfPresent([Lossy<String>].self, forKey: .allergens))?.compactMap(\.value)
        cautions = (try? container.decodeIfPresent([Lossy<String>].self, forKey: .cautions))?.compactMap(\.value)
        title = try? container.decodeIfPresent(String.self, forKey: .title)
        description = try? container.decodeIfPresent(String.self, forKey: .description)
    }

    /// Decodes model output text. Throws `AppError.aiUnavailable` for anything that is not a JSON object.
    static func decode(_ text: String) throws -> RawFoodAnalysis {
        guard let data = text.data(using: .utf8),
              let raw = try? JSONDecoder().decode(RawFoodAnalysis.self, from: data)
        else { throw AppError.aiUnavailable }
        return raw
    }
}

/// Array element that decodes to nil instead of failing the surrounding array.
private nonisolated struct Lossy<Value: Decodable & Sendable>: Decodable, Sendable {
    let value: Value?

    init(from decoder: any Decoder) throws {
        value = try? decoder.singleValueContainer().decode(Value.self)
    }
}
