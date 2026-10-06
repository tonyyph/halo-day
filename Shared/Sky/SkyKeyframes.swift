import Foundation

enum OrbitStyle: String, Sendable { case glow, engraved, ink }

enum SkyID: String, CaseIterable, Codable, Sendable, Identifiable {
    case livingSky, celestial, instrument, aurora, goldenHour, mist
    var id: String { rawValue }
    var title: String {
        switch self {
        case .livingSky: String(localized: "Living Sky")
        case .celestial: String(localized: "Celestial")
        case .instrument: String(localized: "Instrument")
        case .aurora: String(localized: "Aurora")
        case .goldenHour: String(localized: "Golden Hour")
        case .mist: String(localized: "Mist")
        }
    }
    var isPremium: Bool { self != .livingSky && self != .celestial }
    var followsSun: Bool { self == .livingSky }
    var orbitStyle: OrbitStyle {
        switch self {
        case .instrument: .engraved
        case .mist: .ink
        default: .glow
        }
    }
}

struct SkyKeyframe: Sendable {
    var altitude: Double
    var top: SkyColor
    var mid: SkyColor
    var bottom: SkyColor
    var glow: SkyColor
    var stars: Double

    init(_ altitude: Double, _ top: UInt32, _ mid: UInt32, _ bottom: UInt32, glow: UInt32, stars: Double = 0) {
        self.altitude = altitude
        self.top = SkyColor(hex: top); self.mid = SkyColor(hex: mid); self.bottom = SkyColor(hex: bottom)
        self.glow = SkyColor(hex: glow); self.stars = stars
    }
}

/// The only place sky hex values live. Living Sky has separate rising (morning) and
/// setting (evening) tracks, each sorted by sun altitude in degrees.
enum SkyKeyframes {
    static let night = SkyKeyframe(-18, 0x0B0E22, 0x111633, 0x1A1D3A, glow: 0x8EA2FF, stars: 1)
    static let midday = SkyKeyframe(45, 0x6FAAE8, 0xB4D5F2, 0xEEF4F7, glow: 0xFFF4D6)

    static let rising: [SkyKeyframe] = [
        night,
        SkyKeyframe(-9, 0x1B2350, 0x3A3F78, 0x6C5A8E, glow: 0xC7A6FF, stars: 0.45),
        SkyKeyframe(1, 0x8E97D0, 0xE0B2C0, 0xF6CDA9, glow: 0xFFC99A),
        SkyKeyframe(12, 0x8DB4EA, 0xC9D3EE, 0xF6E9DE, glow: 0xFFE2B0),
        midday
    ]
    static let setting: [SkyKeyframe] = [
        night,
        SkyKeyframe(-9, 0x1A1F4A, 0x352F6A, 0x5C3F70, glow: 0xB98CFF, stars: 0.5),
        SkyKeyframe(-3, 0x3B2F63, 0x6E4473, 0x9E5560, glow: 0xFF9A7A, stars: 0.15),
        SkyKeyframe(6, 0xE59A7C, 0xF2B482, 0xF8D7A6, glow: 0xFFB36B),
        SkyKeyframe(22, 0x86B0E0, 0xD2D8E6, 0xF5E6CF, glow: 0xFFE0A6),
        midday
    ]
    static func fixed(_ sky: SkyID) -> SkyKeyframe {
        switch sky {
        case .livingSky, .celestial: SkyKeyframe(0, 0x0A0B1C, 0x12142C, 0x1C1A36, glow: 0x9DB0FF, stars: 1)
        case .aurora: SkyKeyframe(0, 0x06141F, 0x0E2A33, 0x1B2B4A, glow: 0x5CFFC2, stars: 0.7)
        case .instrument: SkyKeyframe(0, 0xF7F1E5, 0xF2EBDD, 0xEAE1CF, glow: 0xE8C9A0)
        case .goldenHour: SkyKeyframe(0, 0xE8A06E, 0xF3BC86, 0xF8DDB0, glow: 0xFFB36B)
        case .mist: SkyKeyframe(0, 0xD9DCE0, 0xE4E6E8, 0xEEEFF0, glow: 0xFFFFFF)
        }
    }
    static let darkInk = SkyColor(hex: 0x161A2B)
    static let lightInk = SkyColor(hex: 0xFBF7F0)
}
