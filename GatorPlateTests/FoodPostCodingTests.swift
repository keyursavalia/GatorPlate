import Foundation
import Testing
@testable import GatorPlate

struct FoodPostCodingTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private var fullPost: FoodPost {
        var post = SampleData.post(now: now)
        post.hasPhoto = true
        post.aiGenerated = true
        post.editedAfterAI = true
        return post
    }

    @Test func dictionaryHasEverySchemaField() {
        let keys = Set(FoodPostCoding.dictionary(from: fullPost).keys)
        let expected: Set<String> = [
            "id", "authorUid", "authorName", "orgName", "title", "description", "items", "overallDietary",
            "allergenWarnings", "cautions", "estimatedServings", "buildingId", "locationName", "locationDetail",
            "latitude", "longitude", "hasPhoto", "aiGenerated", "editedAfterAI", "status", "createdAt", "expiresAt",
            "updatedAt", "deleteAt"
        ]
        #expect(keys == expected)
    }

    @Test func newPostIsActiveWithRawEnumValues() {
        let data = FoodPostCoding.dictionary(from: fullPost)
        #expect(data["status"] as? String == "active")
        #expect(data["overallDietary"] as? String == "vegetarian")
        #expect(data["allergenWarnings"] as? [String] == ["soy", "peanuts"])
    }

    @Test func deleteAtIsExpiryPlusRetention() {
        let post = fullPost
        let data = FoodPostCoding.dictionary(from: post)
        #expect(data["deleteAt"] as? Date == post.expiresAt.addingTimeInterval(24 * 3600))
    }

    @Test func optionalsAreOmittedNotNull() {
        var post = fullPost
        post.orgName = nil
        post.estimatedServings = nil
        post.locationDetail = nil
        let data = FoodPostCoding.dictionary(from: post)
        #expect(data["orgName"] == nil)
        #expect(data["estimatedServings"] == nil)
        #expect(data["locationDetail"] == nil)
    }

    @Test func roundTripsThroughTheDictionary() throws {
        let post = fullPost
        let decoded = try #require(FoodPostCoding.post(from: FoodPostCoding.dictionary(from: post)))
        #expect(decoded == post)
    }

    @Test func itemCaloriesRoundTrip() throws {
        var post = fullPost
        post.items = [
            FoodItem(name: "A", dietary: .vegan, calories: CalorieRange(low: 100, high: 200)),
            FoodItem(name: "B", dietary: .unknown, calories: nil)
        ]
        let decoded = try #require(FoodPostCoding.post(from: FoodPostCoding.dictionary(from: post)))
        #expect(decoded.items == post.items)
    }

    @Test func documentMissingRequiredFieldsDecodesToNil() {
        var data = FoodPostCoding.dictionary(from: fullPost)
        data["expiresAt"] = nil
        #expect(FoodPostCoding.post(from: data) == nil)
        data = FoodPostCoding.dictionary(from: fullPost)
        data["status"] = "bogus"
        #expect(FoodPostCoding.post(from: data) == nil)
    }

    @Test func noRawAIResponseFieldIsStored() {
        let keys = FoodPostCoding.dictionary(from: fullPost).keys
        #expect(!keys.contains { $0.localizedCaseInsensitiveContains("raw") || $0.localizedCaseInsensitiveContains("prompt") })
    }
}
