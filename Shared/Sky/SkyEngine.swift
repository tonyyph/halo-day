import Foundation

enum SkyMoment: String, CaseIterable, Sendable {
    case night, blueHour, dawn, morning, midday, afternoon, goldenHour, dusk
    var title: String {
        switch self {
        case .night: String(localized: "Quiet night")
        case .blueHour: String(localized: "Blue hour")
        case .dawn: String(localized: "Dawn")
        case .morning: String(localized: "Clear morning")
        case .midday: String(localized: "Bright noon")
        case .afternoon: String(localized: "Soft afternoon")
        case .goldenHour: String(localized: "Golden hour")
        case .dusk: String(localized: "Dusk")
        }
    }
}

enum InkScheme: Sendable { case light, dark }

struct SkyState: Equatable, Sendable {
    var top: SkyColor
    var mid: SkyColor
    var bottom: SkyColor
    var glow: SkyColor
    var stars: Double
    var ink: InkScheme
    var inkColor: SkyColor
    var moment: SkyMoment
    var sunAltitude: Double
    var isRising: Bool
    var isNight: Bool { sunAltitude < -6 }
    var stops: [SkyColor] { [top, mid, bottom] }
}

enum SkyEngine {
    static let darkInk = SkyKeyframes.darkInk
    static let lightInk = SkyKeyframes.lightInk
    /// Secondary text is the ink at this opacity; legibility is enforced for it too.
    static let secondaryOpacity = 0.8
    static let minimumContrast = 4.5

    static func state(sky: SkyID, at date: Date, coordinate: GeoCoordinate, calendar: Calendar = .current) -> SkyState {
        let altitude = SolarCalculator.sunAltitude(at: date, coordinate: coordinate)
        let rising = SolarCalculator.sunAltitude(at: date.addingTimeInterval(300), coordinate: coordinate) >= altitude
        let frame = sky.followsSun ? interpolate(rising ? SkyKeyframes.rising : SkyKeyframes.setting, altitude: altitude) : SkyKeyframes.fixed(sky)
        let (ink, stops) = legible([frame.top, frame.mid, frame.bottom])
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let hour = Double(components.hour ?? 0) + Double(components.minute ?? 0) / 60
        return SkyState(top: stops[0], mid: stops[1], bottom: stops[2], glow: frame.glow, stars: frame.stars,
                        ink: ink, inkColor: ink == .light ? lightInk : darkInk,
                        moment: moment(altitude: altitude, rising: rising, hour: hour),
                        sunAltitude: altitude, isRising: rising)
    }

    static func moment(altitude: Double, rising: Bool, hour: Double) -> SkyMoment {
        switch altitude {
        case ..<(-12): .night
        case ..<(-4): .blueHour
        case ..<2: rising ? .dawn : .dusk
        case ..<10: rising ? .dawn : .goldenHour
        default: hour < 11 ? .morning : hour < 14.5 ? .midday : .afternoon
        }
    }

    private static func interpolate(_ frames: [SkyKeyframe], altitude: Double) -> SkyKeyframe {
        guard let first = frames.first, let last = frames.last else { return SkyKeyframes.night }
        if altitude <= first.altitude { return first }
        if altitude >= last.altitude { return last }
        let upperIndex = frames.firstIndex { $0.altitude > altitude }!
        let lower = frames[upperIndex - 1], upper = frames[upperIndex]
        let t = (altitude - lower.altitude) / (upper.altitude - lower.altitude)
        var frame = lower
        frame.altitude = altitude
        frame.top = lower.top.mixed(with: upper.top, t)
        frame.mid = lower.mid.mixed(with: upper.mid, t)
        frame.bottom = lower.bottom.mixed(with: upper.bottom, t)
        frame.glow = lower.glow.mixed(with: upper.glow, t)
        frame.stars = lower.stars + (upper.stars - lower.stars) * t
        return frame
    }

    /// Chooses the ink needing the smaller correction, then nudges each stop just enough
    /// that primary and secondary ink both pass `minimumContrast`.
    private static func legible(_ stops: [SkyColor]) -> (InkScheme, [SkyColor]) {
        func passes(_ ink: SkyColor) -> (SkyColor) -> Bool {
            { stop in
                SkyColor.contrast(ink, stop) >= minimumContrast + 0.01
                    && SkyColor.contrast(ink.composited(over: stop, opacity: secondaryOpacity), stop) >= minimumContrast + 0.01
            }
        }
        let forLight = stops.map { $0.adjusted(towards: .black, until: passes(lightInk)) }
        let forDark = stops.map { $0.adjusted(towards: .white, until: passes(darkInk)) }
        func cost(_ adjusted: [SkyColor]) -> Double {
            zip(stops, adjusted).reduce(0) { $0 + abs($1.0.luminance - $1.1.luminance) }
        }
        return cost(forLight) <= cost(forDark) ? (.light, forLight) : (.dark, forDark)
    }
}
