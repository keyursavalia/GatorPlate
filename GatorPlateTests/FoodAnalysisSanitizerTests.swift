import Foundation
import Testing
@testable import GatorPlate

struct FoodAnalysisSanitizerTests {
    private func raw(
        isFood: Bool? = true, people: Bool? = false, confidence: Double? = 0.9,
        items: [RawFoodAnalysis.Item]? = [.init(name: "Pad thai", dietary: "vegetarian", caloriesLow: 380, caloriesHigh: 520)],
        servings: Int? = 8, allergens: [String]? = ["soy", "peanuts"], cautions: [String]? = [],
        title: String? = "FREE: Pad thai",
        description: String? = "Pad thai noodles and spring rolls. May contain soy and peanuts. Please confirm with the host."
    ) -> RawFoodAnalysis {
        RawFoodAnalysis(
            isFood: isFood, containsPeople: people, confidence: confidence, items: items,
            estimatedServings: servings, allergens: allergens, cautions: cautions,
            title: title, description: description
        )
    }

    private func accepted(_ raw: RawFoodAnalysis) throws -> FoodAnalysisResult {
        guard case .accepted(let result) = FoodAnalysisSanitizer.sanitize(raw) else {
            Issue.record("expected accepted")
            throw AppError.unknown
        }
        return result
    }

    // MARK: Rejections

    @Test func notFoodIsRejected() {
        #expect(FoodAnalysisSanitizer.sanitize(raw(isFood: false)) == .rejected(.notFood))
        #expect(FoodAnalysisSanitizer.sanitize(raw(isFood: nil)) == .rejected(.notFood))
    }

    @Test func peopleAreRejectedEvenWhenFoodIsVisible() {
        #expect(FoodAnalysisSanitizer.sanitize(raw(people: true)) == .rejected(.containsPeople))
    }

    @Test func lowOrMissingConfidenceIsRejected() {
        #expect(FoodAnalysisSanitizer.sanitize(raw(confidence: 0.39)) == .rejected(.lowConfidence))
        #expect(FoodAnalysisSanitizer.sanitize(raw(confidence: nil)) == .rejected(.lowConfidence))
        #expect(FoodAnalysisSanitizer.sanitize(raw(confidence: 0.4)) != .rejected(.lowConfidence))
    }

    @Test func noUsableItemsIsRejected() {
        #expect(FoodAnalysisSanitizer.sanitize(raw(items: [])) == .rejected(.lowConfidence))
        #expect(FoodAnalysisSanitizer.sanitize(raw(items: [.init(name: "  ", dietary: "vegan")])) == .rejected(.lowConfidence))
    }

    // MARK: Clamping

    @Test func overLongDescriptionIsTrimmedAtAWordBoundary() throws {
        let long = String(repeating: "delicious noodles ", count: 20)
        let result = try accepted(raw(description: long))
        #expect(result.description.count <= 150)
        #expect(result.description.hasSuffix("noodles"))
    }

    @Test func emptyDescriptionIsBuiltFromItems() throws {
        let result = try accepted(raw(description: nil))
        #expect(result.description == "Includes Pad thai.")
    }

    @Test func titleGetsPrefixOnceAndIsClamped() throws {
        #expect(try accepted(raw(title: "Pad thai")).title == "FREE: Pad thai")
        #expect(try accepted(raw(title: "free:   Pad thai")).title == "FREE: Pad thai")
        let long = try accepted(raw(title: String(repeating: "word ", count: 40)))
        #expect(long.title.count <= 80)
        #expect(long.title.hasPrefix("FREE: "))
        #expect(try accepted(raw(title: nil)).title == "FREE: Pad thai")
    }

    @Test func emojiAndControlCharactersAreStripped() throws {
        let result = try accepted(raw(title: "FREE: Pizza \u{1F355}", description: "Hot pizza \u{1F525} \u{0007}slices"))
        #expect(result.title == "FREE: Pizza")
        #expect(result.description == "Hot pizza slices")
    }

    @Test func itemsAreCappedAtEight() throws {
        let many = (1...12).map { RawFoodAnalysis.Item(name: "Item \($0)", dietary: "vegan") }
        #expect(try accepted(raw(items: many)).items.count == 8)
    }

    @Test func cautionsAreCappedAtFourAndCleaned() throws {
        let cautions = ["a", " ", "b", "c", "d", "e", "f"]
        #expect(try accepted(raw(cautions: cautions)).cautions == ["a", "b", "c", "d"])
    }

    @Test func caloriesOutsideTheValidRangeAreDropped() {
        #expect(FoodAnalysisSanitizer.calories(low: 380, high: 520) == CalorieRange(low: 380, high: 520))
        #expect(FoodAnalysisSanitizer.calories(low: 0, high: 100) == nil)
        #expect(FoodAnalysisSanitizer.calories(low: -5, high: 100) == nil)
        #expect(FoodAnalysisSanitizer.calories(low: 600, high: 500) == nil)
        #expect(FoodAnalysisSanitizer.calories(low: 100, high: 3001) == nil)
        #expect(FoodAnalysisSanitizer.calories(low: 100, high: nil) == nil)
        #expect(FoodAnalysisSanitizer.calories(low: 100, high: 3000) != nil)
    }

    @Test func servingsOutsideSaneBoundsAreDropped() throws {
        #expect(try accepted(raw(servings: 0)).estimatedServings == nil)
        #expect(try accepted(raw(servings: 9000)).estimatedServings == nil)
        #expect(try accepted(raw(servings: 12)).estimatedServings == 12)
    }

    // MARK: Enums

    @Test func badDietaryValuesBecomeUnknown() throws {
        let items = [
            RawFoodAnalysis.Item(name: "A", dietary: "VEGAN!!"),
            RawFoodAnalysis.Item(name: "B", dietary: nil),
            RawFoodAnalysis.Item(name: "C", dietary: "mixed"),
            RawFoodAnalysis.Item(name: "D", dietary: "non_vegetarian"),
        ]
        #expect(try accepted(raw(items: items)).items.map(\.dietary) == [.unknown, .unknown, .unknown, .nonVegetarian])
    }

    @Test func unknownAllergensAreIgnoredAndDeduped() throws {
        let result = try accepted(raw(allergens: ["Soy", "gluten", "soy", "tree_nuts", "milk"]))
        #expect(result.allergenWarnings == [.milk, .treeNuts, .soy])
        #expect(!result.allergensUnverified)
    }

    @Test func missingAllergensAreFlaggedUnverified() throws {
        #expect(try accepted(raw(allergens: [])).allergensUnverified)
        #expect(try accepted(raw(allergens: nil)).allergensUnverified)
        #expect(try accepted(raw(allergens: ["gluten"])).allergensUnverified)
    }

    // MARK: overallDietary

    @Test(arguments: [
        ([DietaryClass](), DietaryClass.unknown),
        ([.vegan], .vegan),
        ([.vegan, .vegan], .vegan),
        ([.vegan, .vegetarian], .vegetarian),
        ([.vegetarian], .vegetarian),
        ([.nonVegetarian], .nonVegetarian),
        ([.nonVegetarian, .nonVegetarian], .nonVegetarian),
        ([.vegan, .nonVegetarian], .mixed),
        ([.vegetarian, .nonVegetarian], .mixed),
        ([.vegan, .unknown], .unknown),
        ([.nonVegetarian, .unknown], .unknown),
        ([.unknown], .unknown),
    ])
    func overallDietaryTable(classes: [DietaryClass], expected: DietaryClass) {
        #expect(FoodAnalysisSanitizer.overallDietary(for: classes) == expected)
    }

    @Test func localOverallDietaryOverridesAnythingTheModelSays() throws {
        // The schema has no overallDietary field, so a model that sends one is simply ignored.
        let json = #"{"isFood":true,"containsPeople":false,"confidence":0.9,"overallDietary":"vegan","items":[{"name":"Burger","dietary":"non_vegetarian"}],"allergens":[],"title":"Burger","description":"A burger."}"#
        let result = try accepted(try RawFoodAnalysis.decode(json))
        #expect(result.overallDietary == .nonVegetarian)
    }

    @Test func aGuessedVeganItemNextToUnknownNeverYieldsVegan() throws {
        let items = [RawFoodAnalysis.Item(name: "Salad", dietary: "vegan"), RawFoodAnalysis.Item(name: "Dip", dietary: "unknown")]
        #expect(try accepted(raw(items: items)).overallDietary == .unknown)
    }
}

struct RawFoodAnalysisDecodingTests {
    @Test func decodesAWellFormedResponse() throws {
        let json = """
        {"isFood":true,"containsPeople":false,"confidence":0.8,
         "items":[{"name":"Rice","dietary":"vegan","caloriesLow":200,"caloriesHigh":300}],
         "estimatedServings":4,"allergens":["soy"],"cautions":["Keep hot."],
         "title":"FREE: Rice","description":"Rice.","notes":"ignored"}
        """
        let raw = try RawFoodAnalysis.decode(json)
        #expect(raw.isFood == true)
        #expect(raw.items?.first?.caloriesHigh == 300)
        #expect(raw.allergens == ["soy"])
    }

    @Test(arguments: ["", "not json", "[]", "null", "{", "42"])
    func nonObjectJSONThrows(text: String) {
        #expect(throws: AppError.aiUnavailable) { try RawFoodAnalysis.decode(text) }
    }

    @Test func emptyObjectDecodesToAllNil() throws {
        let raw = try RawFoodAnalysis.decode("{}")
        #expect(raw == RawFoodAnalysis())
        #expect(FoodAnalysisSanitizer.sanitize(raw) == .rejected(.notFood))
    }

    @Test func wrongTypesBecomeNilWithoutFailingTheRest() throws {
        let json = #"{"isFood":"yes","confidence":"high","items":"none","title":7,"description":"Okay","allergens":["soy"]}"#
        let raw = try RawFoodAnalysis.decode(json)
        #expect(raw.isFood == nil)
        #expect(raw.confidence == nil)
        #expect(raw.items == nil)
        #expect(raw.title == nil)
        #expect(raw.description == "Okay")
        #expect(raw.allergens == ["soy"])
    }

    @Test func badItemsAreSkippedNotFatal() throws {
        let json = #"{"items":[{"name":"Good","dietary":"vegan"},"junk",42,{"name":"Also good","caloriesLow":"x"}]}"#
        let raw = try RawFoodAnalysis.decode(json)
        #expect(raw.items?.map(\.name) == ["Good", "Also good"])
        #expect(raw.items?.last?.caloriesLow == nil)
    }

    @Test func fractionalCaloriesAndServingsAreRounded() throws {
        let raw = try RawFoodAnalysis.decode(#"{"estimatedServings":7.6,"items":[{"name":"A","caloriesLow":99.6,"caloriesHigh":150}]}"#)
        #expect(raw.estimatedServings == 8)
        #expect(raw.items?.first?.caloriesLow == 100)
    }

    @Test func truncatedJSONThrows() {
        #expect(throws: AppError.aiUnavailable) { try RawFoodAnalysis.decode(#"{"isFood":true,"items":[{"name":"Ri"#) }
    }
}

struct AIValueMappingTests {
    @Test func everyAllergenRoundTripsThroughItsSchemaValue() {
        for allergen in Allergen.allCases {
            #expect(Allergen(schemaValue: allergen.schemaValue) == allergen)
        }
        #expect(Allergen.treeNuts.schemaValue == "tree_nuts")
    }

    @Test func schemaAllergenValuesAreUniqueAndSnakeCase() {
        let values = Allergen.allCases.map(\.schemaValue)
        #expect(Set(values).count == values.count)
        #expect(values.allSatisfy { $0 == $0.lowercased() && !$0.contains(" ") })
    }

    @Test func itemDietaryNeverAcceptsMixed() {
        #expect(DietaryClass(itemSchemaValue: "mixed") == .unknown)
        #expect(DietaryClass(itemSchemaValue: "Non_Vegetarian") == .nonVegetarian)
        #expect(!DietaryClass.itemSchemaValues.contains("mixed"))
    }
}
