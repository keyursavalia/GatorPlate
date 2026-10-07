import FirebaseAILogic

/// Gemini response schema (AI spec section 3). Limits here are hints; `FoodAnalysisSanitizer` enforces them again.
enum FoodAnalysisSchema {
    static let itemDietaryValues = ["vegan", "vegetarian", "non_vegetarian", "unknown"]
    static let overallDietaryValues = ["vegan", "vegetarian", "non_vegetarian", "mixed", "unknown"]
    static let allergenValues = ["milk", "eggs", "fish", "shellfish", "tree_nuts", "peanuts", "wheat", "soy", "sesame"]

    static let item = Schema.object(
        properties: [
            "name": .string(description: "Plain food name a student would recognize"),
            "dietary": .enumeration(values: itemDietaryValues),
            "caloriesLow": .integer(description: "Low estimate, kcal per typical single serving",
                                    minimum: 0, maximum: AppConfig.aiMaxCalories),
            "caloriesHigh": .integer(description: "High estimate, kcal per typical single serving",
                                     minimum: 0, maximum: AppConfig.aiMaxCalories),
        ],
        optionalProperties: ["caloriesLow", "caloriesHigh"],
        propertyOrdering: ["name", "dietary", "caloriesLow", "caloriesHigh"])

    /// `isFood` and `containsPeople` come first so the model decides them before writing any text.
    static let response = Schema.object(
        properties: [
            "isFood": .boolean(),
            "containsPeople": .boolean(description: "True if any identifiable person is visible"),
            "confidence": .double(description: "0 to 1, overall confidence in the identification",
                                  minimum: 0, maximum: 1),
            "items": .array(items: item, maxItems: AppConfig.aiMaxItems),
            "overallDietary": .enumeration(values: overallDietaryValues),
            "estimatedServings": .integer(minimum: AppConfig.aiServingsRange.lowerBound,
                                          maximum: AppConfig.aiServingsRange.upperBound),
            "allergens": .array(items: .enumeration(values: allergenValues),
                                description: "Likely present, not guaranteed"),
            "cautions": .array(items: .string(), maxItems: 3),
            "title": .string(description: "At most 60 characters, starts with FREE: "),
            "description": .string(description: "100 to 150 characters"),
            "notes": .string(description: "Why you were unsure about anything"),
        ],
        optionalProperties: ["estimatedServings", "notes"],
        propertyOrdering: ["isFood", "containsPeople", "confidence", "items", "overallDietary",
                           "estimatedServings", "allergens", "cautions", "title", "description", "notes"])
}
