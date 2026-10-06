import SwiftUI

struct OrbitContent: Sendable {
    var layout: OrbitLayout
    var beads: [OrbitBead] = []
    var focusSpans: [ClosedRange<Double>] = []
    var nightSpans: [ClosedRange<Double>] = []
    var nowHour: Double?
    var moonPhase: Double = 0.5
}

/// The one Orbit renderer shared by the app, widgets, Live Activities, wallpapers and share cards.
struct OrbitCanvas: View {
    var content: OrbitContent
    var sky: SkyState
    var style: OrbitStyle
    var breathing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if breathing && !reduceMotion {
            TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
                canvas(pulse: 1 + 0.06 * sin(timeline.date.timeIntervalSinceReferenceDate * 2 * .pi / 4))
            }
        } else {
            canvas(pulse: 1)
        }
    }

    private func canvas(pulse: Double) -> some View {
        Canvas { context, size in
            let metrics = OrbitMetrics(size: min(size.width, size.height))
            draw(in: &context, metrics: metrics, pulse: pulse)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }

    private var ink: Color { sky.inkColor.color }

    private func ring(_ metrics: OrbitMetrics, radius: CGFloat, from start: Double, to end: Double) -> Path {
        if end - start >= 24 {
            return Path(ellipseIn: CGRect(x: metrics.center.x - radius, y: metrics.center.y - radius, width: radius * 2, height: radius * 2))
        }
        return Path { path in
            path.addArc(center: metrics.center, radius: radius,
                        startAngle: .radians(OrbitGeometry.angle(forHour: start)),
                        endAngle: .radians(OrbitGeometry.angle(forHour: end)), clockwise: false)
        }
    }

    private func eventColor(_ hex: String) -> Color {
        let base = SkyColor(hexString: hex) ?? sky.glow
        return (style == .glow ? base.mixed(with: sky.glow, 0.12) : base.mixed(with: sky.inkColor, 0.15)).color
    }

    private func draw(in context: inout GraphicsContext, metrics: OrbitMetrics, pulse: Double) {
        let center = metrics.center, size = metrics.size

        // 1. Halo / instrument face
        switch style {
        case .glow:
            let haloRadius = size * 0.5
            context.fill(Path(ellipseIn: CGRect(x: center.x - haloRadius, y: center.y - haloRadius, width: haloRadius * 2, height: haloRadius * 2)),
                         with: .radialGradient(Gradient(colors: [sky.glow.color.opacity(0.4), sky.glow.color.opacity(0)]),
                                               center: center, startRadius: 0, endRadius: haloRadius))
        case .engraved:
            let outer = metrics.radius + size * 0.075
            context.stroke(Path(ellipseIn: CGRect(x: center.x - outer, y: center.y - outer, width: outer * 2, height: outer * 2)),
                           with: .color(ink.opacity(0.25)), lineWidth: max(0.5, size * 0.002))
            for hour in 0..<24 {
                let major = hour % 6 == 0
                let a = OrbitGeometry.point(forHour: Double(hour), radius: outer, center: center)
                let b = OrbitGeometry.point(forHour: Double(hour), radius: outer - size * (major ? 0.03 : 0.015), center: center)
                context.stroke(Path { $0.move(to: a); $0.addLine(to: b) }, with: .color(ink.opacity(major ? 0.5 : 0.25)), lineWidth: max(0.5, size * 0.003))
            }
        case .ink:
            break
        }

        // 2. Track and night
        let track = metrics.trackWidth * (style == .ink ? 0.45 : 1)
        context.stroke(ring(metrics, radius: metrics.radius, from: 0, to: 24), with: .color(ink.opacity(style == .ink ? 0.25 : 0.1)), lineWidth: track)
        for span in content.nightSpans where span.upperBound > span.lowerBound {
            context.stroke(ring(metrics, radius: metrics.radius, from: span.lowerBound, to: span.upperBound),
                           with: .color(.black.opacity(sky.ink == .light ? 0.3 : 0.1)), lineWidth: track)
        }
        if style != .engraved {
            for hour in [0.0, 6, 12, 18] {
                let a = OrbitGeometry.point(forHour: hour, radius: metrics.radius + size * 0.05, center: center)
                let b = OrbitGeometry.point(forHour: hour, radius: metrics.radius + size * 0.065, center: center)
                context.stroke(Path { $0.move(to: a); $0.addLine(to: b) }, with: .color(ink.opacity(0.35)), lineWidth: max(0.5, size * 0.003))
            }
        }

        // 3. Events
        let now = content.nowHour ?? 24
        for arc in content.layout.arcs {
            context.stroke(ring(metrics, radius: metrics.laneRadius(arc.lane), from: arc.start, to: arc.end),
                           with: .color(eventColor(arc.colorHex).opacity(arc.end < now ? 0.45 : 1)),
                           style: StrokeStyle(lineWidth: track, lineCap: .round))
        }
        for marker in content.layout.overflow {
            let p = OrbitGeometry.point(forHour: marker.hour, radius: metrics.laneRadius(3), center: center)
            context.draw(Text(verbatim: "+\(marker.count)").font(.system(size: max(7, size * 0.035), weight: .semibold)).foregroundStyle(ink.opacity(0.8)), at: p)
        }

        // 4. Focus sessions
        for span in content.focusSpans {
            context.stroke(ring(metrics, radius: metrics.focusRadius, from: span.lowerBound, to: span.upperBound),
                           with: .color(ink.opacity(0.55)), style: StrokeStyle(lineWidth: max(1, size * 0.012), lineCap: .round))
        }

        // 5. Ritual beads
        for bead in content.beads {
            let p = OrbitGeometry.point(forHour: bead.hour, radius: metrics.beadRadius, center: center)
            let r = size * 0.018
            let color = (SkyColor(hexString: bead.colorHex) ?? sky.glow).color
            let dot = Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
            if bead.isDone {
                var glow = context
                glow.addFilter(.blur(radius: r * 1.2))
                glow.fill(Path(ellipseIn: CGRect(x: p.x - r * 1.8, y: p.y - r * 1.8, width: r * 3.6, height: r * 3.6)), with: .color(color.opacity(0.5)))
                context.fill(dot, with: .color(color))
            } else {
                context.stroke(dot, with: .color(color), lineWidth: max(1, size * 0.005))
            }
        }

        // 6. Now: sun by day, moon by night
        guard let nowHour = content.nowHour else { return }
        let p = OrbitGeometry.point(forHour: nowHour, radius: metrics.radius, center: center)
        let core = size * 0.03
        if sky.isNight {
            let disc = Path(ellipseIn: CGRect(x: p.x - core, y: p.y - core, width: core * 2, height: core * 2))
            var glow = context
            glow.addFilter(.blur(radius: core))
            glow.fill(Path(ellipseIn: CGRect(x: p.x - core * 2, y: p.y - core * 2, width: core * 4, height: core * 4)), with: .color(sky.glow.color.opacity(0.45 * pulse)))
            context.fill(disc, with: .color(SkyEngine.lightInk.color))
            let lit = (1 - cos(2 * .pi * content.moonPhase)) / 2
            let offset = core * 2 * lit * (content.moonPhase < 0.5 ? -1 : 1)
            var shadow = context
            shadow.clip(to: disc)
            shadow.fill(Path(ellipseIn: CGRect(x: p.x - core + offset, y: p.y - core, width: core * 2, height: core * 2)), with: .color(sky.mid.color.opacity(0.92)))
        } else {
            let glowRadius = size * 0.075 * pulse
            var glow = context
            glow.addFilter(.blur(radius: glowRadius * 0.5))
            glow.fill(Path(ellipseIn: CGRect(x: p.x - glowRadius, y: p.y - glowRadius, width: glowRadius * 2, height: glowRadius * 2)),
                      with: .color(sky.glow.mixed(with: .white, 0.3).color.opacity(0.9)))
            context.fill(Path(ellipseIn: CGRect(x: p.x - core, y: p.y - core, width: core * 2, height: core * 2)), with: .color(.white))
        }
    }
}
