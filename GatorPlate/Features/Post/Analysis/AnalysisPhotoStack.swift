import SwiftUI

/// The post flow's photos as a fanned stack (up to 4) with a pill across the bottom edge: "AI drafting" with a scan
/// line while analyzing, or the reason it stopped. `obscured` blurs them (photos rejected for showing people).
struct AnalysisPhotoStack<Badge: View>: View {
    let photos: [CapturedPhoto]
    var isScanning = false
    var obscured = false
    let accessibilityLabel: String
    @ViewBuilder let badge: Badge

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scanOffset: CGFloat = 0

    private static var photoSize: CGFloat { 240 }

    var body: some View {
        let shown = Array(photos.prefix(4))
        ZStack {
            ForEach(Array(shown.enumerated().reversed()), id: \.element.id) { index, photo in
                Image(uiImage: photo.previewImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: Self.photoSize, height: Self.photoSize)
                    .blur(radius: obscured ? 18 : 0, opaque: true)
                    .overlay { if index == 0, isScanning, !reduceMotion { scanLine } }
                    .clipShape(.rect(cornerRadius: Theme.Radius.photo))
                    .overlay {
                        RoundedRectangle(cornerRadius: Theme.Radius.photo).strokeBorder(.background, lineWidth: 3)
                    }
                    .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
                    .rotationEffect(.degrees(fanAngle(index: index, count: shown.count)))
                    .offset(x: fanOffset(index: index, count: shown.count))
            }
        }
        .frame(height: Self.photoSize + 30)
        .overlay(alignment: .bottom) {
            badge.offset(y: Theme.Spacing.sm)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    /// A brand-purple line with a soft glow sweeping down the top photo.
    private var scanLine: some View {
        GeometryReader { proxy in
            LinearGradient(colors: [Theme.Palette.brandPurple.opacity(0), Theme.Palette.brandPurple.opacity(0.45)],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: proxy.size.height * 0.35)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Theme.Palette.brandPurple)
                        .frame(height: 2)
                        .shadow(color: Theme.Palette.brandPurple, radius: 6)
                }
                .offset(y: scanOffset * proxy.size.height - proxy.size.height * 0.35)
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { scanOffset = 1 }
                }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func fanAngle(index: Int, count: Int) -> Double {
        guard count > 1 else { return 0 }
        return (Double(index) - Double(count - 1) / 2) * 6
    }

    private func fanOffset(index: Int, count: Int) -> CGFloat {
        guard count > 1 else { return 0 }
        return (CGFloat(index) - CGFloat(count - 1) / 2) * 18
    }
}

/// A solid status pill for the photo stack (pills over photos never use glass).
struct AnalysisStatusPill: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, 6)
            .background(tint, in: .capsule)
    }
}
