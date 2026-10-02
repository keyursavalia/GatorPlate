import CoreGraphics
import Foundation

/// Self-made stand-in food photos (a plate on a colored table, no people). Used by mocks, previews and the
/// DEBUG-only "sample food photo" button, so the simulator can exercise the whole photo pipeline.
nonisolated enum PlaceholderImage {
    static let variantCount = 3

    private struct Palette {
        let top: (CGFloat, CGFloat, CGFloat)
        let bottom: (CGFloat, CGFloat, CGFloat)
        let food: [(CGFloat, CGFloat, CGFloat)]
    }

    private static let palettes = [
        Palette(top: (0.35, 0.22, 0.12), bottom: (0.18, 0.10, 0.06),
                food: [(0.93, 0.76, 0.35), (0.80, 0.30, 0.20), (0.35, 0.60, 0.25)]),
        Palette(top: (0.12, 0.28, 0.35), bottom: (0.06, 0.14, 0.20),
                food: [(0.95, 0.60, 0.20), (0.98, 0.90, 0.60), (0.55, 0.25, 0.15)]),
        Palette(top: (0.30, 0.15, 0.30), bottom: (0.15, 0.07, 0.17),
                food: [(0.90, 0.45, 0.55), (0.96, 0.85, 0.70), (0.40, 0.65, 0.35)])
    ]

    /// JPEG data for variant `variant` (wraps around). Empty `Data` only if drawing fails.
    static func jpegData(variant: Int = 0, width: Int = 1200, height: Int = 1600, quality: Double = 0.85) -> Data {
        guard let image = makeImage(variant: variant, width: width, height: height),
              let data = try? ImagePreprocessor.encodeJPEG(image, quality: quality)
        else { return Data() }
        return data
    }

    private static func makeImage(variant: Int, width: Int, height: Int) -> CGImage? {
        let palette = palettes[((variant % palettes.count) + palettes.count) % palettes.count]
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        let colors = [
            CGColor(colorSpace: colorSpace, components: [palette.top.0, palette.top.1, palette.top.2, 1]),
            CGColor(colorSpace: colorSpace, components: [palette.bottom.0, palette.bottom.1, palette.bottom.2, 1])
        ].compactMap { $0 }
        if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: [0, 1]) {
            context.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: CGFloat(height)),
                end: .zero,
                options: []
            )
        }

        let center = CGPoint(x: CGFloat(width) / 2, y: CGFloat(height) / 2)
        let plateRadius = CGFloat(min(width, height)) * 0.38
        context.setFillColor(CGColor(gray: 0.95, alpha: 1))
        context.fillEllipse(in: CGRect(
            x: center.x - plateRadius, y: center.y - plateRadius, width: plateRadius * 2, height: plateRadius * 2
        ))
        context.setFillColor(CGColor(gray: 0.85, alpha: 1))
        let rim = plateRadius * 0.82
        context.fillEllipse(in: CGRect(x: center.x - rim, y: center.y - rim, width: rim * 2, height: rim * 2))

        for (index, food) in palette.food.enumerated() {
            let angle = CGFloat(index) * 2 * .pi / CGFloat(palette.food.count) + CGFloat(variant)
            let offset = plateRadius * 0.32
            let radius = plateRadius * 0.28
            let point = CGPoint(x: center.x + cos(angle) * offset, y: center.y + sin(angle) * offset)
            context.setFillColor(CGColor(colorSpace: colorSpace, components: [food.0, food.1, food.2, 1])
                ?? CGColor(gray: 0.5, alpha: 1))
            context.fillEllipse(in: CGRect(
                x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2
            ))
        }
        return context.makeImage()
    }
}
