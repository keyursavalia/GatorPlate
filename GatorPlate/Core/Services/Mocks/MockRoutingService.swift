import Foundation

#if DEBUG
@MainActor
final class MockRoutingService: RoutingService {
    private(set) var openedInMaps: [Coordinate] = []

    func openInAppleMaps(to destination: Coordinate, name: String) {
        openedInMaps.append(destination)
    }
}
#endif
