import MapKit
import OSLog

/// Opens walking directions in Apple Maps.
@MainActor
final class MapKitRoutingService: RoutingService {
    func openInAppleMaps(to destination: Coordinate, name: String) {
        let item = MKMapItem(location: destination.clLocation, address: nil)
        item.name = name
        let opened = item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking])
        if !opened { Logger.services.error("Open in Apple Maps failed") }
    }
}
