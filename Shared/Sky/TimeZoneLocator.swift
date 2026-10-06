import Foundation

/// Coarse location used to place the sun when the person declines location access.
enum TimeZoneLocator {
    static func approximateCoordinate(for timeZone: TimeZone, at date: Date = .now) -> GeoCoordinate {
        if let city = cities[timeZone.identifier] { return GeoCoordinate(latitude: city.0, longitude: city.1) }
        return GeoCoordinate(latitude: 0, longitude: Double(timeZone.secondsFromGMT(for: date)) / 240)
    }

    private static let cities: [String: (Double, Double)] = [
        "Asia/Ho_Chi_Minh": (10.82, 106.63), "Asia/Saigon": (10.82, 106.63), "Asia/Bangkok": (13.75, 100.50),
        "Asia/Singapore": (1.35, 103.82), "Asia/Tokyo": (35.68, 139.69), "Asia/Seoul": (37.57, 126.98),
        "Asia/Shanghai": (31.23, 121.47), "Asia/Hong_Kong": (22.32, 114.17), "Asia/Taipei": (25.03, 121.56),
        "Asia/Manila": (14.60, 120.98), "Asia/Jakarta": (-6.21, 106.85), "Asia/Kolkata": (28.61, 77.21),
        "Asia/Calcutta": (28.61, 77.21), "Asia/Dubai": (25.20, 55.27), "Europe/London": (51.51, -0.13),
        "Europe/Paris": (48.86, 2.35), "Europe/Berlin": (52.52, 13.40), "Europe/Madrid": (40.42, -3.70),
        "Europe/Rome": (41.90, 12.50), "Europe/Amsterdam": (52.37, 4.90), "Europe/Moscow": (55.76, 37.62),
        "Europe/Oslo": (59.91, 10.75), "America/New_York": (40.71, -74.01), "America/Chicago": (41.88, -87.63),
        "America/Denver": (39.74, -104.99), "America/Los_Angeles": (34.05, -118.24), "America/Toronto": (43.65, -79.38),
        "America/Vancouver": (49.28, -123.12), "America/Mexico_City": (19.43, -99.13), "America/Sao_Paulo": (-23.55, -46.63),
        "Australia/Sydney": (-33.87, 151.21), "Australia/Melbourne": (-37.81, 144.96), "Pacific/Auckland": (-36.85, 174.76),
        "Africa/Cairo": (30.04, 31.24), "Africa/Johannesburg": (-26.20, 28.05)
    ]
}
