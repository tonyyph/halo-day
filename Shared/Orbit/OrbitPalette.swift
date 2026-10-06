import SwiftUI

/// Colour rules shared by the full Orbit and the mini-orbits.
enum OrbitPalette {
    /// Light skies deepen event colours toward the ink so pastels stay visible; dark skies tint them with the glow.
    static func eventColor(_ hex: String, sky: SkyState) -> Color {
        let base = SkyColor(hexString: hex) ?? sky.glow
        return (sky.ink == .dark ? base.mixed(with: sky.inkColor, 0.22) : base.mixed(with: sky.glow, 0.12)).color
    }
    /// Warm ritual light, deepened on bright skies so it stays visible.
    static func ritualColor(sky: SkyState) -> Color {
        (sky.ink == .dark ? SkyKeyframes.focusGlow.mixed(with: sky.inkColor, 0.35) : SkyKeyframes.focusGlow).color
    }
}

enum OrbitPath {
    /// An arc of the 24-hour ring from `start` to `end` hours; a full day becomes a circle.
    static func arc(center: CGPoint, radius: CGFloat, from start: Double, to end: Double) -> Path {
        guard end > start else { return Path() }
        if end - start >= 24 {
            return Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        }
        return Path { path in
            path.addArc(center: center, radius: radius,
                        startAngle: .radians(OrbitGeometry.angle(forHour: start)),
                        endAngle: .radians(OrbitGeometry.angle(forHour: end)), clockwise: false)
        }
    }
}
