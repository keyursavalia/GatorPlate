import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import GatorPlate

struct ImageSizeCapTests {
    @Test func smallPhotoIsReturnedUntouched() throws {
        let photo = try ImagePreprocessor.process(data: PlaceholderImage.jpegData())
        #expect(ImagePreprocessor.fittingCap(photo.jpegData, maxBytes: AppConfig.maxImageBytes) == photo.jpegData)
    }

    @Test func oversizedPhotoIsReencodedUnderTheCap() throws {
        let photo = try ImagePreprocessor.process(data: PlaceholderImage.jpegData())
        // A cap just under the current size forces at least one smaller step.
        let cap = photo.jpegData.count - 1
        let result = try #require(ImagePreprocessor.fittingCap(photo.jpegData, maxBytes: cap))
        #expect(result.count <= cap)
        #expect(!ImageMetadata.hasGPS(result))
    }

    @Test func impossibleCapReturnsNilSoThePostGoesOutWithoutAPhoto() throws {
        let photo = try ImagePreprocessor.process(data: PlaceholderImage.jpegData())
        #expect(ImagePreprocessor.fittingCap(photo.jpegData, maxBytes: 10) == nil)
    }

    @Test func notAnImageReturnsNil() {
        #expect(ImagePreprocessor.fittingCap(Data("not an image".utf8), maxBytes: 5) == nil)
    }

    @Test func capSettingsOnlyGetSmaller() {
        let steps = ImagePreprocessor.capSteps
        for (earlier, later) in zip(steps, steps.dropFirst()) {
            #expect(later.longEdge <= earlier.longEdge)
            #expect(later.longEdge < earlier.longEdge || later.quality < earlier.quality)
        }
    }

    @Test func capMatchesTheRulesLimit() {
        #expect(AppConfig.maxImageBytes == 300_000)
    }
}
