import Foundation
import CoreGraphics

struct OrbitArc: Identifiable, Hashable, Sendable {
    var id: String
    var start: Double
    var end: Double
    var lane: Int
    var colorHex: String
    var continuesBefore: Bool
    var continuesAfter: Bool
}

struct OrbitOverflow: Hashable, Sendable {
    var hour: Double
    var count: Int
}

struct OrbitBead: Identifiable, Hashable, Sendable {
    var id: UUID
    var hour: Double
    var isDone: Bool
    var colorHex: String
}

enum OrbitHit: Equatable { case now, bead(UUID), arc(String) }

struct OrbitMetrics {
    var size: CGFloat
    var center: CGPoint { CGPoint(x: size / 2, y: size / 2) }
    var radius: CGFloat { size * 0.39 }
    var trackWidth: CGFloat { size * 0.052 }
    var beadRadius: CGFloat { radius - size * 0.085 }
    var focusRadius: CGFloat { radius - size * 0.05 }
    var hitTolerance: CGFloat { 22 }
    func laneRadius(_ lane: Int) -> CGFloat { radius + CGFloat(lane) * trackWidth * 1.15 }
}

/// Events for one day, laid out on the 24-hour ring. All-day events are excluded;
/// overlapping events take outward lanes, and anything past `maxLanes` becomes an overflow marker.
struct OrbitLayout: Sendable {
    var arcs: [OrbitArc]
    var overflow: [OrbitOverflow]

    init(day: Date, events: [CalendarEvent], calendar: Calendar = .current, maxLanes: Int = 3, minimumSpan: Double = 0.25) {
        let dayStart = calendar.startOfDay(for: day)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
        let timed = events
            .filter { !$0.isAllDay && $0.startDate < dayEnd && $0.endDate > dayStart }
            .sorted { ($0.startDate, $0.endDate, $0.id) < ($1.startDate, $1.endDate, $1.id) }
        var laneEnds: [Double] = []
        var arcs: [OrbitArc] = []
        var overflow: [OrbitOverflow] = []
        for event in timed {
            let start = max(0, event.startDate.timeIntervalSince(dayStart) / 3600)
            let rawEnd = min(24, event.endDate.timeIntervalSince(dayStart) / 3600)
            let end = min(24, max(rawEnd, start + minimumSpan))
            if let lane = (0..<maxLanes).first(where: { $0 >= laneEnds.count || laneEnds[$0] <= start }) {
                if lane < laneEnds.count { laneEnds[lane] = end } else { laneEnds.append(end) }
                arcs.append(OrbitArc(id: event.id, start: start, end: end, lane: lane, colorHex: event.accentColor,
                                     continuesBefore: event.startDate < dayStart, continuesAfter: event.endDate > dayEnd))
            } else if let last = overflow.last, start - last.hour < 1 {
                overflow[overflow.count - 1].count += 1
            } else {
                overflow.append(OrbitOverflow(hour: start, count: 1))
            }
        }
        self.arcs = arcs
        self.overflow = overflow
    }
}

enum OrbitGeometry {
    /// Radians in y-down space: noon at the top, midnight at the bottom, 06:00 left, 18:00 right.
    static func angle(forHour hour: Double) -> Double { (180 + (hour - 6) * 15) * .pi / 180 }

    static func hour(forAngle angle: Double) -> Double {
        let hour = (angle * 180 / .pi - 180) / 15 + 6
        let wrapped = hour.truncatingRemainder(dividingBy: 24)
        return wrapped < 0 ? wrapped + 24 : wrapped
    }

    static func point(forHour hour: Double, radius: CGFloat, center: CGPoint) -> CGPoint {
        let a = angle(forHour: hour)
        return CGPoint(x: center.x + radius * cos(a), y: center.y + radius * sin(a))
    }

    static func hour(at point: CGPoint, center: CGPoint) -> Double {
        hour(forAngle: atan2(point.y - center.y, point.x - center.x))
    }

    static func hours(of date: Date, calendar: Calendar) -> Double {
        date.timeIntervalSince(calendar.startOfDay(for: date)) / 3600
    }

    static func nightSpans(_ day: SolarDay, calendar: Calendar) -> [ClosedRange<Double>] {
        switch day {
        case .polarDay: return []
        case .polarNight: return [0...24]
        case let .normal(sunrise, sunset):
            return [0...hours(of: sunrise, calendar: calendar), hours(of: sunset, calendar: calendar)...24]
        }
    }

    static func hitTest(_ point: CGPoint, metrics: OrbitMetrics, layout: OrbitLayout, beads: [OrbitBead], nowHour: Double?) -> OrbitHit? {
        func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat { hypot(a.x - b.x, a.y - b.y) }
        if let nowHour, distance(point, self.point(forHour: nowHour, radius: metrics.radius, center: metrics.center)) <= metrics.hitTolerance {
            return .now
        }
        if let bead = beads
            .map({ ($0, distance(point, self.point(forHour: $0.hour, radius: metrics.beadRadius, center: metrics.center))) })
            .filter({ $0.1 <= metrics.hitTolerance })
            .min(by: { $0.1 < $1.1 })?.0 {
            return .bead(bead.id)
        }
        let radial = distance(point, metrics.center)
        let hour = self.hour(at: point, center: metrics.center)
        let padding = 0.2
        return layout.arcs.first { arc in
            abs(radial - metrics.laneRadius(arc.lane)) <= metrics.trackWidth / 2 + metrics.hitTolerance / 2
                && hour >= arc.start - padding && hour <= arc.end + padding
        }.map { .arc($0.id) }
    }
}
