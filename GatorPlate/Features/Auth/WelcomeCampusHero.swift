import MapKit
import SwiftUI

/// Welcome screen hero: a still, tilted SFSU map where demo posts drop in one by one while a sample "Free food on
/// campus" notification slides down for each, a preview of what the app does. Decorative (hidden from VoiceOver;
/// the feature list says the same). With Reduce Motion every pin is placed and one notification shows, still.
struct WelcomeCampusHero: View {
    private struct DemoPost: Identifiable {
        let id: String
        let food: String
        let buildingId: String
        let minutesLeft: Int
        let dietary: DietaryClass

        var place: String { CampusBuilding.byId(buildingId)?.shortName ?? "" }
        var coordinate: CLLocationCoordinate2D? { CampusBuilding.byId(buildingId)?.coordinate.clLocationCoordinate }
    }

    private static let demoPosts = [
        DemoPost(id: "pizza", food: "Pizza", buildingId: "chavez", minutesLeft: 28, dietary: .vegetarian),
        DemoPost(id: "tacos", food: "Tacos", buildingId: "library", minutesLeft: 45, dietary: .nonVegetarian),
        DemoPost(id: "bagels", food: "Bagels", buildingId: "humanities", minutesLeft: 17, dietary: .vegan),
    ]

    /// A little north of the demo pins, so they land between the notification and the app tile.
    private static var cameraCenter: CLLocationCoordinate2D {
        let coordinates = demoPosts.compactMap(\.coordinate)
        guard !coordinates.isEmpty else { return SFSUCampus.homeCoordinate.clLocationCoordinate }
        let latitude = coordinates.map(\.latitude).reduce(0, +) / Double(coordinates.count)
        let longitude = coordinates.map(\.longitude).reduce(0, +) / Double(coordinates.count)
        return CLLocationCoordinate2D(latitude: latitude + 0.0007, longitude: longitude)
    }

    /// Seconds each notification stays before the next post drops in.
    private static let beatSeconds = 3.0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var droppedCount = 0
    @State private var bannerIndex: Int?

    var body: some View {
        Map(initialPosition: .camera(MapCamera(centerCoordinate: Self.cameraCenter,
                                               distance: 1300, heading: 20, pitch: 50)),
            interactionModes: []) {
            ForEach(Array(Self.demoPosts.enumerated()), id: \.element.id) { index, post in
                if let coordinate = post.coordinate {
                    Annotation(post.food, coordinate: coordinate, anchor: .bottom) {
                        PostPin(dietary: post.dietary, isSelected: false)
                            .offset(y: index < droppedCount ? 0 : -60)
                            .opacity(index < droppedCount ? 1 : 0)
                    }
                    .annotationTitles(.hidden)
                }
            }
        }
        .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .excludingAll))
        .allowsHitTesting(false)
        .overlay(alignment: .top) { banner }
        .clipShape(.rect(cornerRadius: 28))
        // Fades into the page so the app tile can sit across the bottom edge.
        .mask {
            LinearGradient(stops: [.init(color: .black, location: 0.62), .init(color: .clear, location: 1)],
                           startPoint: .top, endPoint: .bottom)
        }
        .accessibilityHidden(true)
        .task { await play() }
    }

    @ViewBuilder
    private var banner: some View {
        if let bannerIndex {
            let post = Self.demoPosts[bannerIndex]
            NotificationPreview(title: "Free food on campus",
                                message: "\(post.food) at \(post.place) · \(post.minutesLeft) min left")
                .padding(Theme.Spacing.md)
                .id(post.id)
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    /// Drops each post with its notification, then starts over, until the view goes away.
    private func play() async {
        guard !reduceMotion else {
            droppedCount = Self.demoPosts.count
            bannerIndex = 0
            return
        }
        try? await Task.sleep(for: .seconds(0.6))
        while !Task.isCancelled {
            for index in Self.demoPosts.indices {
                withAnimation(.spring(duration: 0.55, bounce: 0.45)) {
                    droppedCount = max(droppedCount, index + 1)
                    bannerIndex = index
                }
                try? await Task.sleep(for: .seconds(Self.beatSeconds))
                guard !Task.isCancelled else { return }
            }
            withAnimation(.easeInOut(duration: 0.4)) {
                bannerIndex = nil
                droppedCount = 0
            }
            try? await Task.sleep(for: .seconds(0.8))
        }
    }
}

/// A lock-screen style notification: app tile, app name, "now", a bold title and one line.
private struct NotificationPreview: View {
    let title: String
    let message: String

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: "fork.knife")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(Theme.Palette.brandPurple, in: .rect(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(title).font(.subheadline.weight(.semibold))
                    Spacer(minLength: Theme.Spacing.sm)
                    Text("now").font(.caption).foregroundStyle(.secondary)
                }
                Text(message)
                    .font(.subheadline)
                    .lineLimit(1)
            }
        }
        .padding(Theme.Spacing.md)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
        .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
    }
}

#Preview {
    WelcomeCampusHero()
        .frame(height: 320)
        .padding()
}
