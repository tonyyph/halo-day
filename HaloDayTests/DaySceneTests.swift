import XCTest
@testable import HaloDay

final class DaySceneTests: XCTestCase {
    private let calendar = Calendar.current
    private var day: Date { calendar.date(from: DateComponents(year: 2026, month: 10, day: 5))! }
    private func at(_ hour: Double, _ base: Date? = nil) -> Date { (base ?? day).addingTimeInterval(hour * 3600) }
    private var solar: SolarDay { .normal(sunrise: at(6), sunset: at(18)) }
    private func event(_ id: String, _ start: Double, _ end: Double, allDay: Bool = false) -> CalendarEvent {
        CalendarEvent(id: id, title: id, startDate: at(start), endDate: at(end), calendarName: "Work", accentColor: "E2607D", isAllDay: allDay)
    }
    private var events: [CalendarEvent] {
        [event("standup", 9, 9.5), event("review", 10.5, 11.25), event("lunch", 13, 14), event("pilates", 14.25, 15), event("all", 0, 24, allDay: true)]
    }
    private func phase(_ scene: DayScene, _ id: String) -> DayColumnItem.Phase? {
        for item in scene.column { if case let .event(event, phase) = item.kind, event.id == id { return phase } }
        return nil
    }

    func testTodayColumnOrdersPastNowNextAndGaps() {
        let scene = DaySceneBuilder.build(day: day, now: at(10.08), events: events, habits: [], focusSessions: [], solar: solar, calendar: calendar)
        XCTAssertEqual(scene.column.map(\.id), ["standup", "now", "review", "gap-lunch", "lunch", "pilates"])
        XCTAssertEqual(phase(scene, "standup"), .past)
        XCTAssertEqual(phase(scene, "review"), .next)
        XCTAssertEqual(phase(scene, "lunch"), .later)
        XCTAssertEqual(scene.column[1].kind, .now(freeMinutes: 25))
        XCTAssertEqual(scene.column[3].kind, .gap(minutes: 105))
        XCTAssertEqual(scene.nextEvent?.id, "review")
        XCTAssertEqual(scene.allDay.map(\.id), ["all"])
        XCTAssertTrue(scene.isToday)
        XCTAssertEqual(scene.orbit.nowHour ?? 0, 10.08, accuracy: 0.001)
    }
    func testCurrentEventSuppressesFreeTime() {
        let scene = DaySceneBuilder.build(day: day, now: at(10.75), events: events, habits: [], focusSessions: [], solar: solar, calendar: calendar)
        XCTAssertEqual(scene.column.map(\.id), ["standup", "review", "now", "gap-lunch", "lunch", "pilates"])
        XCTAssertEqual(phase(scene, "review"), .current)
        XCTAssertEqual(scene.column[2].kind, .now(freeMinutes: nil))
        XCTAssertEqual(scene.nextEvent?.id, "review")
    }
    func testOtherDaysHaveNoNowAndNoGaps() {
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: day)!
        let scene = DaySceneBuilder.build(day: tomorrow, now: at(10), events: events.map { var e = $0; e.startDate += 86400; e.endDate += 86400; return e },
                                          habits: [], focusSessions: [], solar: solar, calendar: calendar)
        XCTAssertFalse(scene.isToday)
        XCTAssertNil(scene.orbit.nowHour)
        XCTAssertEqual(scene.column.map(\.id), ["standup", "review", "lunch", "pilates"])
        XCTAssertEqual(phase(scene, "standup"), .later)
        XCTAssertNil(scene.nextEvent)
    }
    func testBeadsSpreadWithinTheirSlot() {
        let habits = [Habit(title: "a", icon: "drop", accentColor: "E0904A", timeOfDay: .morning),
                      Habit(title: "b", icon: "drop", accentColor: "E0904A", timeOfDay: .morning),
                      Habit(title: "c", icon: "drop", accentColor: "E0904A", timeOfDay: .morning),
                      Habit(title: "d", icon: "drop", accentColor: "E0904A", timeOfDay: .evening)]
        let hours = DaySceneBuilder.beads(for: habits, on: day).map(\.hour)
        XCTAssertEqual(hours[0], 7.5, accuracy: 0.0001)
        XCTAssertEqual(hours[1], 8.1, accuracy: 0.0001)
        XCTAssertEqual(hours[2], 6.9, accuracy: 0.0001)
        XCTAssertEqual(hours[3], 20, accuracy: 0.0001)
    }
    func testFocusSpansAndMinutes() {
        let done = FocusSession(title: "a", startDate: at(8), endDate: at(8.5), durationMinutes: 30, accentColor: "D4AF6A", isActive: false)
        let active = FocusSession(title: "b", startDate: at(10), endDate: at(10.5), durationMinutes: 30, accentColor: "D4AF6A")
        let yesterday = FocusSession(title: "c", startDate: at(-14), endDate: at(-13), durationMinutes: 60, accentColor: "D4AF6A", isActive: false)
        let scene = DaySceneBuilder.build(day: day, now: at(10.25), events: [], habits: [], focusSessions: [active, done, yesterday], solar: solar, calendar: calendar)
        XCTAssertEqual(scene.orbit.focusSpans.count, 2)
        XCTAssertEqual(scene.orbit.focusSpans[0].upperBound, 10.25, accuracy: 0.001)
        XCTAssertEqual(scene.focusMinutes, 30)
        XCTAssertFalse(scene.hasTimedEvents)
        XCTAssertEqual(scene.column.map(\.id), ["now"])
    }
}
