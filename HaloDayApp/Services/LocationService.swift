import CoreLocation

@MainActor
protocol LocationProviding: AnyObject {
    func approximateCoordinate() async throws -> GeoCoordinate
}

/// One reduced-accuracy fix, used only to place the sun. Rounded to 0.1° and kept on device.
@MainActor
final class LocationService: NSObject, CLLocationManagerDelegate, LocationProviding {
    enum LocationError: LocalizedError {
        case denied, unavailable
        var errorDescription: String? {
            switch self {
            case .denied: String(localized: "Location is off for Halo Day. The sky follows your time zone instead.")
            case .unavailable: String(localized: "Your location isn't available right now. The sky follows your time zone instead.")
            }
        }
    }

    private let manager = CLLocationManager()
    /// Everyone waiting for the one in-flight request; a second call joins it instead of cancelling it.
    private var waiters: [CheckedContinuation<GeoCoordinate, any Error>] = []

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyReduced
    }

    nonisolated static func rounded(_ coordinate: CLLocationCoordinate2D) -> GeoCoordinate {
        GeoCoordinate(latitude: (coordinate.latitude * 10).rounded() / 10, longitude: (coordinate.longitude * 10).rounded() / 10)
    }

    func approximateCoordinate() async throws -> GeoCoordinate {
        try await withCheckedThrowingContinuation { continuation in
            waiters.append(continuation)
            guard waiters.count == 1 else { return }
            switch manager.authorizationStatus {
            case .notDetermined: manager.requestWhenInUseAuthorization()
            case .denied, .restricted: finish(.failure(LocationError.denied))
            default: manager.requestLocation()
            }
        }
    }

    private func finish(_ result: Result<GeoCoordinate, any Error>) {
        let waiting = waiters
        waiters = []
        waiting.forEach { $0.resume(with: result) }
    }

    private func authorizationChanged() {
        guard !waiters.isEmpty else { return }
        switch manager.authorizationStatus {
        case .notDetermined: break
        case .denied, .restricted: finish(.failure(LocationError.denied))
        default: manager.requestLocation()
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in self.authorizationChanged() }
    }
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let coordinate = locations.last.map { Self.rounded($0.coordinate) }
        Task { @MainActor in self.finish(coordinate.map { .success($0) } ?? .failure(LocationError.unavailable)) }
    }
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        Task { @MainActor in self.finish(.failure(LocationError.unavailable)) }
    }
}
