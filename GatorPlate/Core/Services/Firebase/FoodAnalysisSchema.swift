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

    /// One per input photo; `index` is the N in its "Photo N:" label.
    static let photo = Schema.object(
        properties: [
            "index": .integer(description: "The N from the photo's label", minimum: 1, maximum: AppConfig.postMaxPhotos),
            "isFood": .boolean(description: "This photo shows edible food or drink"),
            "containsPeople": .boolean(description: "Any identifiable person is visible in this photo"),
        ],
        propertyOrdering: ["index", "isFood", "containsPeople"])

    /// The per-photo flags and `isFood`/`containsPeople` come first so the model decides them before writing text.
    static let response = Schema.object(
        properties: [
            "photos": .array(items: photo, maxItems: AppConfig.postMaxPhotos),
            "isFood": .boolean(description: "True if at least one photo shows food"),
            "containsPeople": .boolean(description: "True if any photo shows an identifiable person"),
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
        propertyOrdering: ["photos", "isFood", "containsPeople", "confidence", "items", "overallDietary",
                           "estimatedServings", "allergens", "cautions", "title", "description", "notes"])
}
