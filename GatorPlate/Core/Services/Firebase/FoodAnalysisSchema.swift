import FirebaseAILogic

/// Response schema for structured output (`docs/04-AI-GEMINI-SPEC.md` section 3).
/// `overallDietary` is deliberately absent: the app computes it locally from the items.
nonisolated enum FoodAnalysisSchema {
    static let schema: Schema = .object(
        properties: [
            "isFood": .boolean(),
            "containsPeople": .boolean(),
            "confidence": .double(),
            "items": .array(
                items: .object(
                    properties: [
                        "name": .string(),
                        "dietary": .enumeration(values: DietaryClass.itemSchemaValues),
                        "caloriesLow": .integer(),
                        "caloriesHigh": .integer(),
                    ],
                    optionalProperties: ["caloriesLow", "caloriesHigh"]
                ),
                maxItems: FoodAnalysisSanitizer.maxItems
            ),
            "estimatedServings": .integer(),
            "allergens": .array(items: .enumeration(values: Allergen.allCases.map(\.schemaValue))),
            "cautions": .array(items: .string(), maxItems: 3),
            "title": .string(),
            "description": .string(),
        ],
        optionalProperties: ["estimatedServings"]
    )

    /// Gemini 3.x ignores temperature/topK/topP and rejects penalties and candidateCount, so none are set.
    static let generationConfig = GenerationConfig(
        maxOutputTokens: 1024,
        responseMIMEType: "application/json",
        responseSchema: schema
    )
}
