import Foundation

/// Raw model JSON. Every field is optional and decoded leniently: wrong types become nil, bad array
/// elements are skipped, and decoding never fails because of one field.
nonisolated struct RawFoodAnalysis: Decodable, Sendable {
    struct Item: Decodable, Sendable {
        var name: String?
        var dietary: String?
        var caloriesLow: Int?
        var caloriesHigh: Int?

        private enum CodingKeys: String, CodingKey {
            case name, dietary, caloriesLow, caloriesHigh
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            name = container.lenientString(.name)
            dietary = container.lenientString(.dietary)
            caloriesLow = container.lenientInt(.caloriesLow)
            caloriesHigh = container.lenientInt(.caloriesHigh)
        }
    }

    /// One entry per input photo (prompt v2). `index` is 1-based, matching the "Photo N:" labels.
    struct Photo: Decodable, Sendable {
        var index: Int?
        var isFood: Bool?
        var containsPeople: Bool?

        private enum CodingKeys: String, CodingKey {
            case index, isFood, containsPeople
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            index = container.lenientInt(.index)
            isFood = container.lenientBool(.isFood)
            containsPeople = container.lenientBool(.containsPeople)
        }
    }

    /// At least one photo shows food.
    var isFood: Bool?
    /// Any photo shows an identifiable person.
    var containsPeople: Bool?
    var photos: [Photo]
    var confidence: Double?
    var items: [Item]
    var overallDietary: String?
    var estimatedServings: Int?
    var allergens: [String]
    var cautions: [String]
    var title: String?
    var description: String?

    private enum CodingKeys: String, CodingKey {
        case isFood, containsPeople, photos, confidence, items, overallDietary, estimatedServings
        case allergens, cautions, title, description
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isFood = container.lenientBool(.isFood)
        containsPeople = container.lenientBool(.containsPeople)
        photos = container.lenientArray(.photos, of: Photo.self)
        confidence = container.lenientDouble(.confidence)
        items = container.lenientArray(.items, of: Item.self)
        overallDietary = container.lenientString(.overallDietary)
        estimatedServings = container.lenientInt(.estimatedServings)
        allergens = container.lenientArray(.allergens, of: String.self)
        cautions = container.lenientArray(.cautions, of: String.self)
        title = container.lenientString(.title)
        description = container.lenientString(.description)
    }
}

/// Decodes anything and discards it; used to step over bad array elements.
private nonisolated struct SkippedElement: Decodable {
    init(from decoder: any Decoder) throws {}
}

private nonisolated extension KeyedDecodingContainer {
    func lenientString(_ key: Key) -> String? {
        (try? decodeIfPresent(String.self, forKey: key)) ?? nil
    }

    func lenientBool(_ key: Key) -> Bool? {
        if let value = try? decodeIfPresent(Bool.self, forKey: key) { return value }
        switch lenientString(key)?.lowercased() {
        case "true": return true
        case "false": return false
        default: return nil
        }
    }

    func lenientDouble(_ key: Key) -> Double? {
        if let value = try? decodeIfPresent(Double.self, forKey: key) { return value.isFinite ? value : nil }
        return lenientString(key).flatMap(Double.init)
    }

    func lenientInt(_ key: Key) -> Int? {
        if let value = try? decodeIfPresent(Int.self, forKey: key) { return value }
        guard let value = lenientDouble(key), value.magnitude < Double(Int32.max) else { return nil }
        return Int(value.rounded())
    }

    func lenientArray<Element: Decodable>(_ key: Key, of type: Element.Type) -> [Element] {
        guard var container = try? nestedUnkeyedContainer(forKey: key) else { return [] }
        var elements: [Element] = []
        while !container.isAtEnd {
            if let element = try? container.decode(Element.self) {
                elements.append(element)
            } else if (try? container.decode(SkippedElement.self)) == nil {
                break
            }
        }
        return elements
    }
}
