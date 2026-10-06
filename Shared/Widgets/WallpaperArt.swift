import SwiftUI

/// A Lock Screen wallpaper: the sky full-bleed with a faint Orbit low on the screen, leaving the clock area clean.
struct WallpaperArt: View {
    var sky: SkyState
    var orbit: OrbitContent?
    var style: OrbitStyle

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                SkyBackground(state: sky)
                if let orbit {
                    OrbitCanvas(content: orbit, sky: sky, style: style)
                        .frame(width: proxy.size.width * 0.7, height: proxy.size.width * 0.7)
                        .opacity(0.55)
                        .position(x: proxy.size.width / 2, y: proxy.size.height * 0.66)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

/// When a wallpaper's sky is drawn.
enum WallpaperMoment: String, CaseIterable, Identifiable, Sendable {
    case now, dawn, morning, golden, night
    var id: String { rawValue }
    var title: String {
        switch self {
        case .now: String(localized: "Now")
        case .dawn: String(localized: "Dawn")
        case .morning: String(localized: "Morning")
        case .golden: String(localized: "Golden hour")
        case .night: String(localized: "Night")
        }
    }
    func date(on day: Date, now: Date, calendar: Calendar = .current) -> Date {
        let hour: Double = switch self {
        case .now: OrbitGeometry.hours(of: now, calendar: calendar)
        case .dawn: 6 + 10.0 / 60
        case .morning: 9.5
        case .golden: 17 + 20.0 / 60
        case .night: 22.5
        }
        return calendar.startOfDay(for: day).addingTimeInterval(hour * 3600)
    }
    /// Free tier: Living Sky at dawn, and Celestial (spec §4.5).
    static func isFree(sky: SkyID, moment: WallpaperMoment) -> Bool {
        sky == .celestial || (sky == .livingSky && moment == .dawn)
    }
}
