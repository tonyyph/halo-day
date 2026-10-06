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
    /// Peak combined opacity of the sky glow and the Orbit halo behind text (0.35 sky glow under a 0.4 halo).
    static let maximumGlowOpacity = 1 - (1 - 0.35) * (1 - 0.4)

    static func state(sky: SkyID, at date: Date, coordinate: GeoCoordinate, calendar: Calendar = .current) -> SkyState {
        let altitude = effectiveAltitude(at: date, coordinate: coordinate, calendar: calendar)
        let slope = SolarCalculator.sunAltitude(at: date.addingTimeInterval(300), coordinate: coordinate)
            - SolarCalculator.sunAltitude(at: date.addingTimeInterval(-300), coordinate: coordinate)
        let rising = slope >= 0
        let frame = sky.followsSun ? blended(altitude: altitude, slope: slope) : SkyKeyframes.fixed(sky)
        let (ink, stops, glow) = legible([frame.top, frame.mid, frame.bottom], glow: frame.glow)
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let hour = Double(components.hour ?? 0) + Double(components.minute ?? 0) / 60
        return SkyState(top: stops[0], mid: stops[1], bottom: stops[2], glow: glow, stars: frame.stars,
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

    /// The dimmed "focus dusk": the current sky pulled 35% toward night with a warm glow, always light ink.
    static func focusDusk(_ state: SkyState) -> SkyState {
        let night = SkyKeyframes.night
        let pulled = zip(state.stops, [night.top, night.mid, night.bottom]).map { $0.mixed(with: $1, 0.35) }
        let (_, stops, glow) = legible(pulled, glow: state.glow.mixed(with: SkyKeyframes.focusGlow, 0.5), forcing: .light)
        var dusk = state
        dusk.top = stops[0]; dusk.mid = stops[1]; dusk.bottom = stops[2]
        dusk.glow = glow
        dusk.ink = .light
        dusk.inkColor = lightInk
        dusk.stars = max(state.stars, 0.3)
        return dusk
    }

    /// Polar night holds the night phase and polar day holds daylight (spec §8).
    private static func effectiveAltitude(at date: Date, coordinate: GeoCoordinate, calendar: Calendar) -> Double {
        let altitude = SolarCalculator.sunAltitude(at: date, coordinate: coordinate)
        switch SolarCalculator.day(containing: date, coordinate: coordinate, calendar: calendar) {
        case .polarNight: return min(altitude, -18)
        case .polarDay: return max(altitude, 12)
        case .normal: return altitude
        }
    }

    /// Blends the morning and evening tracks by how fast the sun is climbing, so the sky never
    /// snaps between them at solar noon or midnight when the sun culminates low.
    private static func blended(altitude: Double, slope: Double) -> SkyKeyframe {
        let risingWeight = 0.5 + 0.5 * min(1, max(-1, slope / 1.5))
        let morning = interpolate(SkyKeyframes.rising, altitude: altitude)
        let evening = interpolate(SkyKeyframes.setting, altitude: altitude)
        var frame = evening
        frame.top = evening.top.mixed(with: morning.top, risingWeight)
        frame.mid = evening.mid.mixed(with: morning.mid, risingWeight)
        frame.bottom = evening.bottom.mixed(with: morning.bottom, risingWeight)
        frame.glow = evening.glow.mixed(with: morning.glow, risingWeight)
        frame.stars = evening.stars + (morning.stars - evening.stars) * risingWeight
        return frame
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

    /// Chooses the ink needing the smaller correction, nudges each stop just enough that primary and
    /// secondary ink pass `minimumContrast`, then tones the glow so text over sky glow + Orbit halo still passes.
    private static func legible(_ stops: [SkyColor], glow: SkyColor, forcing forced: InkScheme? = nil) -> (InkScheme, [SkyColor], SkyColor) {
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
        let ink: InkScheme = forced ?? (cost(forLight) <= cost(forDark) ? .light : .dark)
        let adjusted = ink == .light ? forLight : forDark
        let check = passes(ink == .light ? lightInk : darkInk)
        let toned = glow.adjusted(towards: ink == .light ? .black : .white) { candidate in
            adjusted.allSatisfy { check(candidate.composited(over: $0, opacity: maximumGlowOpacity)) }
        }
        return (ink, adjusted, toned)
    }
}
