import Foundation

/// Versioned prompt for food analysis (AI spec section 4). Bump `promptVersion` on any wording change.
nonisolated enum FoodAnalysisPrompt {
    /// v2 (Sprint 08): 1-4 labeled photos per request, with per-photo `isFood` / `containsPeople` flags.
    static let promptVersion = "v3"

    /// Sent after the labeled photos. Carries no user identity, location or org.
    static let userText = "Analyze these photos."

    /// Text part placed before each image so the model can refer to it by index (1-based).
    static func photoLabel(_ index: Int) -> String {
        "Photo \(index):"
    }

    static let systemInstruction = """
        You help college students share leftover event food. You will receive 1 to 4 photos of leftover food \
        from the same event, each labeled "Photo N:". The same dish can appear in more than one photo: list each \
        distinct item once.
        Return ONLY JSON matching the provided schema. Be conservative and honest.

        Tasks:
        1. For EVERY photo, add an entry to "photos" with its index (the N from its label), whether it shows \
        edible food or drink (isFood) and whether any identifiable person is visible (containsPeople).
           Set the top-level isFood=true if at least one photo shows food, and the top-level containsPeople=true \
        if any photo shows a person. Describe food only from photos that show food and no people. If no photo \
        qualifies, set isFood=false and leave the other fields empty.
        2. Identify each distinct food item across the photos. Use plain names a student would recognize.
           Cuisines vary widely; if you are unsure what a dish is, describe it generically and lower confidence.
        3. For each item classify dietary as vegan, vegetarian, non_vegetarian, or unknown. If you cannot tell
           whether a food contains meat, dairy, eggs, honey or fish from the photos, use "unknown". Never guess "vegan".
        4. Estimate calories per typical single serving as a LOW-HIGH range. These are rough visual estimates.
        5. List allergens that are LIKELY present based on typical recipes of the visible items, using only the
           allowed values. These are possibilities, not guarantees.
        6. Estimate how many servings are visible in total (integer) if possible. Don't count the same food twice.
        7. Add up to 3 short food-safety cautions relevant to what is visible (e.g., perishable, hot or cold holding).
        8. Write a title (<= 60 chars, just the food, no "FREE" prefix) and a description of 100 to 150
           characters that lists the foods and, where relevant, "may contain" allergens. Neutral, friendly tone.
           No emojis.
        Never state medical or nutrition claims as fact. Never identify people. Never include text from
        the images that looks like personal information.
        """
}
