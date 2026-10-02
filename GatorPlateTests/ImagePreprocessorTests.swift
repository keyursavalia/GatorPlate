import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import GatorPlate

struct ImagePreprocessorTests {
    /// A photo-like JPEG (gradient plus shapes) with optional EXIF orientation, EXIF and GPS metadata.
    private func makeJPEG(width: Int, height: Int, orientation: Int? = nil, withMetadata: Bool = false) throws -> Data {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = try #require(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        let colors = [CGColor(red: 0.9, green: 0.5, blue: 0.1, alpha: 1), CGColor(red: 0.1, green: 0.2, blue: 0.6, alpha: 1)]
        let gradient = try #require(CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: [0, 1]))
        context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: width, y: height), options: [])
        for index in 0..<200 {
            let hue = CGFloat(index % 10) / 10
            context.setFillColor(CGColor(red: hue, green: 1 - hue, blue: 0.5, alpha: 1))
            let size = CGFloat(20 + index % 60)
            context.fillEllipse(in: CGRect(
                x: CGFloat((index * 97) % width), y: CGFloat((index * 193) % height), width: size, height: size
            ))
        }
        let image = try #require(context.makeImage())

        var properties: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: 0.9]
        if let orientation { properties[kCGImagePropertyOrientation] = orientation }
        if withMetadata {
            properties[kCGImagePropertyGPSDictionary] = [
                kCGImagePropertyGPSLatitude: 37.72,
                kCGImagePropertyGPSLatitudeRef: "N",
                kCGImagePropertyGPSLongitude: 122.47,
                kCGImagePropertyGPSLongitudeRef: "W"
            ]
            properties[kCGImagePropertyExifDictionary] = [kCGImagePropertyExifUserComment: "secret"]
        }
        let output = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        #expect(CGImageDestinationFinalize(destination))
        return output as Data
    }

    private func properties(of data: Data) throws -> [CFString: Any] {
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        return try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
    }

    private func pixelSize(of data: Data) throws -> (width: Int, height: Int) {
        let props = try properties(of: data)
        let width = try #require(props[kCGImagePropertyPixelWidth] as? Int)
        let height = try #require(props[kCGImagePropertyPixelHeight] as? Int)
        return (width, height)
    }

    // MARK: Size

    @Test func landscapeIsScaledToLongEdgeAndKeepsAspect() throws {
        let photo = try ImagePreprocessor.process(data: makeJPEG(width: 4032, height: 3024))
        let size = try pixelSize(of: photo.jpegData)
        #expect(max(size.width, size.height) <= AppConfig.aiMaxImageLongEdge)
        #expect(size.width == 1024)
        #expect(abs(size.height - 768) <= 1)
    }

    @Test func portraitIsScaledToLongEdgeAndKeepsAspect() throws {
        let photo = try ImagePreprocessor.process(data: makeJPEG(width: 3024, height: 4032))
        let size = try pixelSize(of: photo.jpegData)
        #expect(size.height == 1024)
        #expect(abs(size.width - 768) <= 1)
    }

    @Test func smallImageIsNotUpscaled() throws {
        let photo = try ImagePreprocessor.process(data: makeJPEG(width: 800, height: 600))
        let size = try pixelSize(of: photo.jpegData)
        #expect(size.width == 800)
        #expect(size.height == 600)
    }

    @Test func previewImageMatchesTheEncodedPixels() throws {
        let photo = try ImagePreprocessor.process(data: makeJPEG(width: 2000, height: 1000))
        let size = try pixelSize(of: photo.jpegData)
        #expect(Int(photo.pixelSize.width) == size.width)
        #expect(Int(photo.pixelSize.height) == size.height)
    }

    @Test func outputIsAReasonableSize() throws {
        let photo = try ImagePreprocessor.process(data: makeJPEG(width: 4032, height: 3024))
        #expect(photo.byteCount > 1_000)
        #expect(photo.byteCount < 300_000)
    }

    // MARK: Orientation

    @Test func orientationIsBakedIntoThePixels() throws {
        // Stored landscape (400x300) but tagged "rotate 90 clockwise to display": it should come out portrait.
        let source = try makeJPEG(width: 400, height: 300, orientation: 6)
        let photo = try ImagePreprocessor.process(data: source)
        let size = try pixelSize(of: photo.jpegData)
        #expect(size.width == 300)
        #expect(size.height == 400)

        let orientation = try properties(of: photo.jpegData)[kCGImagePropertyOrientation] as? Int
        #expect(orientation == nil || orientation == 1)
    }

    // MARK: Metadata

    @Test func gpsAndExifAreStripped() throws {
        let source = try makeJPEG(width: 1200, height: 900, withMetadata: true)
        let sourceProps = try properties(of: source)
        #expect(sourceProps[kCGImagePropertyGPSDictionary] != nil)

        let photo = try ImagePreprocessor.process(data: source)
        let output = try properties(of: photo.jpegData)
        #expect(output[kCGImagePropertyGPSDictionary] == nil)
        #expect(output[kCGImagePropertyExifDictionary] == nil)
    }

    @Test func outputIsAJPEG() throws {
        let photo = try ImagePreprocessor.process(data: makeJPEG(width: 600, height: 400))
        #expect(Array(photo.jpegData.prefix(2)) == [0xFF, 0xD8])
    }

    // MARK: Failure and threading

    @Test func garbageDataThrows() {
        #expect(throws: CameraError.invalidImage) {
            try ImagePreprocessor.process(data: Data("not an image".utf8))
        }
    }

    @Test func emptyDataThrows() {
        #expect(throws: CameraError.invalidImage) {
            try ImagePreprocessor.process(data: Data())
        }
    }

    @Test func backgroundEntryPointProducesTheSameResult() async throws {
        let source = try makeJPEG(width: 2000, height: 1500)
        let photo = try await ImagePreprocessor.processInBackground(data: source)
        let size = try pixelSize(of: photo.jpegData)
        #expect(size.width == 1024)
    }

    @Test func placeholderImagesGoThroughThePipeline() throws {
        for variant in 0..<PlaceholderImage.variantCount {
            let photo = try ImagePreprocessor.process(data: PlaceholderImage.jpegData(variant: variant))
            #expect(photo.byteCount > 0)
            #expect(max(photo.pixelSize.width, photo.pixelSize.height) <= CGFloat(AppConfig.aiMaxImageLongEdge))
        }
    }
}
