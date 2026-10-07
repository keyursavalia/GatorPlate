import MapKit
import SwiftUI

/// Campus-locked map with a fixed center pin. The spot must be inside the campus outline.
struct PinDropMapView: View {
    let onConfirm: (PostLocation) -> Void

    @State private var position: MapCameraPosition
    @State private var center: Coordinate

    /// The full campus rectangle (not the map tab's inset region) so pins can reach the edges, including UPN.
    private static let bounds = MapCameraBounds(centerCoordinateBounds: SFSUCampus.region,
                                                minimumDistance: SFSUCampus.minCameraDistance,
                                                maximumDistance: SFSUCampus.maxCameraDistance)
    private static let startDistance: CLLocationDistance = 600

    init(initial: Coordinate?, onConfirm: @escaping (PostLocation) -> Void) {
        let start = initial ?? SFSUCampus.homeCoordinate
        self.onConfirm = onConfirm
        _center = State(initialValue: start)
        _position = State(initialValue: .camera(MapCamera(centerCoordinate: start.clLocationCoordinate,
                                                          distance: Self.startDistance)))
    }

    var body: some View {
        Map(position: $position, bounds: Self.bounds, interactionModes: [.pan, .zoom, .rotate])
            .mapStyle(.standard(emphasis: .muted, pointsOfInterest: .including([.university, .library, .cafe, .restaurant])))
            .onMapCameraChange(frequency: .continuous) { context in
                center = Coordinate(context.region.center)
            }
            .overlay { centerPin }
            .safeAreaInset(edge: .bottom) { footer }
            .navigationTitle("Drop a pin")
            .navigationBarTitleDisplayMode(.inline)
            .accessibilityElement(children: .contain)
    }

    private var centerPin: some View {
        Image(systemName: "mappin")
            .font(.system(size: 40, weight: .semibold))
            .foregroundStyle(isValid ? Theme.Palette.brandPurple : Theme.Palette.danger)
            .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
            // The pin's tip marks the center.
            .offset(y: -20)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private var footer: some View {
        VStack(spacing: Theme.Spacing.md) {
            Label(statusText, systemImage: isValid ? "checkmark.circle.fill" : "xmark.octagon.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isValid ? Color.primary : Theme.Palette.danger)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel(statusText)
            PrimaryButton(title: "Use this spot") {
                guard isValid, let nearest = CampusBuilding.nearest(to: center) else { return }
                onConfirm(.pin(center, nearest: nearest))
            }
            .disabled(!isValid)
            .opacity(isValid ? 1 : 0.5)
            .accessibilityHint(isValid ? "" : "Move the map so the pin is on campus")
        }
        .padding(Theme.Spacing.lg)
        .background(.background)
    }

    private var isValid: Bool {
        SFSUCampus.isValidPinLocation(center)
    }

    private var statusText: String {
        guard isValid, let nearest = CampusBuilding.nearest(to: center) else {
            return "Move the map so the pin is on campus."
        }
        return "Near \(nearest.name)"
    }
}

#Preview {
    NavigationStack {
        PinDropMapView(initial: nil) { _ in }
    }
}
