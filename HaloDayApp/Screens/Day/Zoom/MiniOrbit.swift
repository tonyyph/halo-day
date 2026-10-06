import SwiftUI

/// A small ring for one day: thicker when busier, arcs in calendar colours, an inner ring of ritual light.
struct MiniOrbit: View {
    var mini: MiniDay
    var sky: SkyState
    var nowHour: Double?

    var body: some View {
        Canvas { context, size in
            let side = min(size.width, size.height)
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = side * 0.4
            let width = side * (0.055 + 0.06 * min(mini.busyHours, 8) / 8)
            let ink = sky.inkColor.color
            context.stroke(OrbitPath.arc(center: center, radius: radius, from: 0, to: 24), with: .color(ink.opacity(0.14)), lineWidth: width)
            for arc in mini.arcs {
                context.stroke(OrbitPath.arc(center: center, radius: radius, from: arc.start, to: arc.end),
                               with: .color(OrbitPalette.eventColor(arc.colorHex, sky: sky)),
                               style: StrokeStyle(lineWidth: width, lineCap: .round))
            }
            if mini.ritualsTotal > 0, mini.ritualsDone > 0 {
                let fraction = Double(mini.ritualsDone) / Double(mini.ritualsTotal)
                let ritual = OrbitPalette.ritualColor(sky: sky)
                context.stroke(OrbitPath.arc(center: center, radius: radius * 0.66, from: 12, to: 12 + 24 * fraction),
                               with: .color(mini.allRitualsDone ? ritual : ritual.opacity(0.55)),
                               style: StrokeStyle(lineWidth: max(1, side * 0.035), lineCap: .round))
            }
            if let nowHour {
                let point = OrbitGeometry.point(forHour: nowHour, radius: radius, center: center)
                let dot = side * 0.07
                context.fill(Path(ellipseIn: CGRect(x: point.x - dot, y: point.y - dot, width: dot * 2, height: dot * 2)), with: .color(.white))
            }
        }
        .accessibilityHidden(true)
    }
}
