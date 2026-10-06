import Foundation

struct DayColumnItem: Identifiable, Hashable, Sendable {
    enum Phase: Hashable, Sendable { case past, current, next, later }
    enum Kind: Hashable, Sendable {
        case event(CalendarEvent, Phase)
        case now(freeMinutes: Int?)
        case gap(minutes: Int)
    }
    var id: String
    var date: Date
    var kind: Kind
}

/// Everything the Day screen draws for one calendar day.
struct DayScene: Sendable {
    var day: Date
    var isToday: Bool
    var orbit: OrbitContent
    var allDay: [CalendarEvent]
    var column: [DayColumnItem]
    var nextEvent: CalendarEvent?
    var ritualsDone: Int
    var ritualsTotal: Int
    var focusMinutes: Int
    var hasTimedEvents: Bool
}

enum DaySceneBuilder {
    static let minimumGapMinutes = 20

    static func build(day: Date, now: Date, events: [CalendarEvent], habits: [Habit], focusSessions: [FocusSession],
                      solar: SolarDay, calendar: Calendar = .current) -> DayScene {
        let dayStart = calendar.startOfDay(for: day)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
        let isToday = calendar.isDate(now, inSameDayAs: dayStart)
        let onDay = events.filter { $0.startDate < dayEnd && $0.endDate > dayStart }
        let timed = onDay.filter { !$0.isAllDay }.sorted { ($0.startDate, $0.endDate, $0.id) < ($1.startDate, $1.endDate, $1.id) }
        let orbit = OrbitContent(
            layout: OrbitLayout(day: dayStart, events: timed, calendar: calendar),
            beads: beads(for: habits, on: dayStart),
            focusSpans: focusSpans(focusSessions, day: dayStart, now: now, calendar: calendar),
            nightSpans: OrbitGeometry.nightSpans(solar, calendar: calendar),
            nowHour: isToday ? OrbitGeometry.wallHours(of: now, relativeTo: dayStart, calendar: calendar) : nil,
            moonPhase: SolarCalculator.moonPhase(at: isToday ? now : dayStart.addingTimeInterval(12 * 3600)))
        let (column, next) = column(timed: timed, dayStart: dayStart, now: now, isToday: isToday)
        let finished = focusSessions.filter { !$0.isActive && calendar.isDate($0.startDate, inSameDayAs: dayStart) }
        return DayScene(day: dayStart, isToday: isToday, orbit: orbit, allDay: onDay.filter(\.isAllDay), column: column, nextEvent: next,
                        ritualsDone: habits.filter { $0.isCompleted(on: dayStart) }.count, ritualsTotal: habits.count,
                        focusMinutes: finished.reduce(0) { $0 + max(0, Int($1.endDate.timeIntervalSince($1.startDate) / 60)) },
                        hasTimedEvents: !timed.isEmpty)
    }

    /// Beads sit at their slot's anchor; several in one slot fan out ±0.6 h around it.
    static func beads(for habits: [Habit], on day: Date) -> [OrbitBead] {
        var counts: [TimeOfDay: Int] = [:]
        return habits.map { habit in
            let index = counts[habit.timeOfDay, default: 0]
            counts[habit.timeOfDay] = index + 1
            let step = Double((index + 1) / 2) * 0.6 * (index % 2 == 1 ? 1 : -1)
            return OrbitBead(id: habit.id, hour: habit.timeOfDay.anchorHour + step, isDone: habit.isCompleted(on: day), colorHex: habit.accentColor)
        }
    }

    static func focusSpans(_ sessions: [FocusSession], day: Date, now: Date, calendar: Calendar) -> [ClosedRange<Double>] {
        sessions.compactMap { session in
            let end = session.isActive ? min(now, session.endDate) : session.endDate
            let start = max(0, OrbitGeometry.wallHours(of: session.startDate, relativeTo: day, calendar: calendar))
            let stop = min(24, OrbitGeometry.wallHours(of: end, relativeTo: day, calendar: calendar))
            return stop > start ? start...stop : nil
        }
    }

    private static func column(timed: [CalendarEvent], dayStart: Date, now: Date, isToday: Bool) -> ([DayColumnItem], CalendarEvent?) {
        guard isToday else {
            let phase: DayColumnItem.Phase = dayStart < now ? .past : .later
            return (timed.map { DayColumnItem(id: $0.id, date: $0.startDate, kind: .event($0, phase)) }, nil)
        }
        let current = timed.filter { $0.startDate <= now && $0.endDate > now }
        let upcoming = timed.filter { $0.startDate > now }
        var items: [DayColumnItem] = timed.map { event in
            let phase: DayColumnItem.Phase
            if event.endDate <= now { phase = .past }
            else if event.startDate <= now { phase = .current }
            else if current.isEmpty && event.id == upcoming.first?.id { phase = .next }
            else { phase = .later }
            return DayColumnItem(id: event.id, date: event.startDate, kind: .event(event, phase))
        }
        let free = current.isEmpty ? upcoming.first.map { Int($0.startDate.timeIntervalSince(now) / 60) } : nil
        items.append(DayColumnItem(id: "now", date: now, kind: .now(freeMinutes: free)))
        var reach = current.map(\.endDate).max()
        for event in upcoming {
            if let start = reach {
                let minutes = Int(event.startDate.timeIntervalSince(start) / 60)
                if minutes >= minimumGapMinutes {
                    items.append(DayColumnItem(id: "gap-\(event.id)", date: start, kind: .gap(minutes: minutes)))
                }
            }
            reach = max(reach ?? event.endDate, event.endDate)
        }
        let sorted = items.enumerated().sorted { ($0.element.date, $0.offset) < ($1.element.date, $1.offset) }.map(\.element)
        return (sorted, current.first ?? upcoming.first)
    }
}
