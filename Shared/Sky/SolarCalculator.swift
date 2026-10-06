import Foundation

struct GeoCoordinate: Codable, Hashable, Sendable {
    var latitude: Double
    var longitude: Double
}

enum SolarDay: Equatable, Sendable {
    case normal(sunrise: Date, sunset: Date)
    case polarDay
    case polarNight
}

/// NOAA solar position equations (accurate to about a minute between ±72° latitude).
enum SolarCalculator {
    static func sunAltitude(at date: Date, coordinate: GeoCoordinate) -> Double {
        let (declination, equationOfTime) = parameters(julianDay: julianDay(date))
        let seconds = date.timeIntervalSince1970
        let utcMinutes = (seconds - (seconds / 86400).rounded(.down) * 86400) / 60
        var trueSolar = (utcMinutes + equationOfTime + 4 * coordinate.longitude).truncatingRemainder(dividingBy: 1440)
        if trueSolar < 0 { trueSolar += 1440 }
        let hourAngle = trueSolar / 4 - 180
        let lat = radians(coordinate.latitude), dec = radians(declination)
        let cosZenith = sin(lat) * sin(dec) + cos(lat) * cos(dec) * cos(radians(hourAngle))
        return 90 - degrees(acos(min(1, max(-1, cosZenith))))
    }

    static func day(containing date: Date, coordinate: GeoCoordinate, calendar: Calendar) -> SolarDay {
        let start = calendar.startOfDay(for: date)
        let localNoon = start.addingTimeInterval(12 * 3600)
        let (declination, equationOfTime) = parameters(julianDay: julianDay(localNoon))
        let lat = radians(coordinate.latitude), dec = radians(declination)
        let cosHourAngle = cos(radians(90.833)) / (cos(lat) * cos(dec)) - tan(lat) * tan(dec)
        if cosHourAngle > 1 { return .polarNight }
        if cosHourAngle < -1 { return .polarDay }
        let halfDayMinutes = degrees(acos(cosHourAngle)) * 4
        let utcMidnight = (localNoon.timeIntervalSince1970 / 86400).rounded(.down) * 86400
        var noon = Date(timeIntervalSince1970: utcMidnight + (720 - 4 * coordinate.longitude - equationOfTime) * 60)
        let end = start.addingTimeInterval(86400)
        while noon < start { noon.addTimeInterval(86400) }
        while noon >= end { noon.addTimeInterval(-86400) }
        return .normal(sunrise: noon.addingTimeInterval(-halfDayMinutes * 60), sunset: noon.addingTimeInterval(halfDayMinutes * 60))
    }

    /// Mean synodic phase: 0 new, 0.5 full.
    static func moonPhase(at date: Date) -> Double {
        let cycles = (julianDay(date) - 2451550.26) / 29.530588853
        let phase = cycles - cycles.rounded(.down)
        return phase < 0 ? phase + 1 : phase
    }

    // MARK: - NOAA terms

    private static func julianDay(_ date: Date) -> Double { date.timeIntervalSince1970 / 86400 + 2440587.5 }
    private static func radians(_ value: Double) -> Double { value * .pi / 180 }
    private static func degrees(_ value: Double) -> Double { value * 180 / .pi }

    /// Declination (degrees) and equation of time (minutes).
    private static func parameters(julianDay: Double) -> (Double, Double) {
        let t = (julianDay - 2451545) / 36525
        var meanLongitude = (280.46646 + t * (36000.76983 + t * 0.0003032)).truncatingRemainder(dividingBy: 360)
        if meanLongitude < 0 { meanLongitude += 360 }
        let anomaly = radians(357.52911 + t * (35999.05029 - 0.0001537 * t))
        let eccentricity = 0.016708634 - t * (0.000042037 + 0.0000001267 * t)
        let center = sin(anomaly) * (1.914602 - t * (0.004817 + 0.000014 * t))
            + sin(2 * anomaly) * (0.019993 - 0.000101 * t) + sin(3 * anomaly) * 0.000289
        let omega = radians(125.04 - 1934.136 * t)
        let apparentLongitude = radians(meanLongitude + center - 0.00569 - 0.00478 * sin(omega))
        let seconds = 21.448 - t * (46.815 + t * (0.00059 - t * 0.001813))
        let obliquity = radians(23 + (26 + seconds / 60) / 60 + 0.00256 * cos(omega))
        let declination = degrees(asin(sin(obliquity) * sin(apparentLongitude)))
        let y = pow(tan(obliquity / 2), 2)
        let l0 = radians(meanLongitude)
        let equation = y * sin(2 * l0) - 2 * eccentricity * sin(anomaly)
            + 4 * eccentricity * y * sin(anomaly) * cos(2 * l0)
            - 0.5 * y * y * sin(4 * l0) - 1.25 * eccentricity * eccentricity * sin(2 * anomaly)
        return (declination, 4 * degrees(equation))
    }
}
