import CoreLocation
import Foundation
import Combine

struct Coordinates: Equatable {
    let latitude: Double
    let longitude: Double
}

@MainActor
final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var coordinates: Coordinates?
    @Published private(set) var statusMessage: String?

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func locate() {
        guard CLLocationManager.locationServicesEnabled() else {
            statusMessage = "La localisation est désactivée sur cet iPhone."
            return
        }
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            statusMessage = "Autorise la localisation dans Réglages pour trier les stations par distance."
        default:
            manager.requestLocation()
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedAlways || manager.authorizationStatus == .authorizedWhenInUse {
            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        coordinates = Coordinates(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        statusMessage = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        statusMessage = "Position indisponible : \(error.localizedDescription)"
    }
}
