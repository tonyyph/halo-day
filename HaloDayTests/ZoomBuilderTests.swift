import XCTest
@testable import HaloDay

final class ZoomBuilderTests: XCTestCase {
    private func calendar(firstWeekday: Int) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.firstWeekday = firstWeekday
        return calendar
    }
    private func date(_ day: Int, _ hour: Double = 0, month: Int = 10, calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day))!.addingTimeInterval(hour * 3600)
    }
    private func event(_ id: String, _ start: Date, _ end: Date, allDay: Bool = false) -> CalendarEvent {
        CalendarEvent(id: id, title: id, startDate: start, endDate: end, calendarName: "x", accentColor: "5B74D6", isAllDay: allDay)
    }

    func testWeekStartsOnTheLocaleFirstWeekday() {
        let monday = calendar(firstWeekday: 2)
        let week = ZoomBuilder.week(containing: date(7, calendar: monday), now: date(7, 10, calendar: monday), events: [], habits: [], calendar: monday)
        XCTAssertEqual(week.count, 7)
        XCTAssertEqual(monday.component(.day, from: week[0].day), 5)
        XCTAssertTrue(week[2].isToday)
        let sunday = calendar(firstWeekday: 1)
        XCTAssertEqual(sunday.component(.day, from: ZoomBuilder.week(containing: date(7, calendar: sunday), now: date(7, calendar: sunday), events: [], habits: [], calendar: sunday)[0].day), 4)
    }
    func testMonthGridPadsToWholeWeeks() {
        let monday = calendar(firstWeekday: 2)
        let rows = ZoomBuilder.month(containing: date(20, calendar: monday), now: date(5, calendar: monday), events: [], habits: [], calendar: monday)
        XCTAssertEqual(rows.count, 5)
        XCTAssertTrue(rows.allSatisfy { $0.count == 7 })
        XCTAssertNil(rows[0][2])
        XCTAssertEqual(rows[0][3].map { monday.component(.day, from: $0.day) }, 1)     // 1 Oct 2026 is a Thursday
        XCTAssertEqual(rows[4][5].map { monday.component(.day, from: $0.day) }, 31)
        XCTAssertNil(rows[4][6])
        XCTAssertEqual(rows.flatMap { $0 }.compactMap { $0 }.count, 31)
        XCTAssertEqual(rows[0][3]?.key, "2026-10-01")
    }
    func testBusyHoursMergesOverlapsClipsMidnightAndIgnoresAllDay() {
        let utc = calendar(firstWeekday: 2)
        let day = date(5, calendar: utc)
        let events = [event("a", date(5, 9, calendar: utc), date(5, 11, calendar: utc)), event("b", date(5, 10, calendar: utc), date(5, 12, calendar: utc)),
                      event("c", date(5, 13, calendar: utc), date(5, 14, calendar: utc)), event("all", day, date(6, calendar: utc), allDay: true),
                      event("late", date(5, 23, calendar: utc), date(6, 2, calendar: utc))]
        XCTAssertEqual(ZoomBuilder.busyHours(events, dayStart: day, calendar: utc), 5, accuracy: 0.0001)
        let mini = ZoomBuilder.miniDay(day, now: day, events: events, habits: [], calendar: utc)
        XCTAssertEqual(mini.eventCount, 5)
        XCTAssertEqual(mini.arcs.count, 4)
    }
    func testRitualCompletionPerDay() {
        let calendar = Calendar.current
        let day = calendar.date(from: DateComponents(year: 2026, month: 10, day: 6))!
        let habit = Habit(title: "Read", icon: "book", accentColor: "B0152F", completedDates: [day])
        let week = ZoomBuilder.week(containing: day, now: day, events: [], habits: [habit], calendar: calendar)
        XCTAssertEqual(week.filter(\.allRitualsDone).map { calendar.component(.day, from: $0.day) }, [6])
    }
    func testZoomLevelsStepAndClamp() {
        XCTAssertEqual(ZoomLevel.day.zoomedOut, .week)
        XCTAssertEqual(ZoomLevel.month.zoomedOut, .month)
        XCTAssertEqual(ZoomLevel.day.zoomedIn, .day)
        XCTAssertEqual(ZoomLevel.month.zoomedIn, .week)
    }
}
