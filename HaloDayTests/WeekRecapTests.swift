import XCTest
@testable import HaloDay

final class WeekRecapTests: XCTestCase {
    private let calendar = Calendar.current
    private var wednesday: Date { calendar.date(from: DateComponents(year: 2026, month: 10, day: 7, hour: 15))! }
    private func day(_ offset: Int, _ hour: Double = 0) -> Date {
        calendar.startOfDay(for: wednesday).addingTimeInterval(Double(offset) * 86400 + hour * 3600)
    }
    private func focus(_ offset: Int, _ minutes: Int) -> FocusSession {
        FocusSession(title: "f", startDate: day(offset, 9), endDate: day(offset, 9).addingTimeInterval(Double(minutes * 60)), durationMinutes: minutes, accentColor: "D4AF6A", isActive: false)
    }

    func testFocusIsTalliedPerDayOfTheWeek() {
        let recap = WeekRecapBuilder.build(containing: wednesday, now: wednesday, events: [], habits: [], focusSessions: [focus(0, 50), focus(0, 25), focus(-1, 30), focus(-30, 90)], calendar: calendar)
        XCTAssertEqual(recap.days.count, 7)
        XCTAssertEqual(recap.focusMinutes, 105)
        let index = recap.days.firstIndex { calendar.isDate($0.day, inSameDayAs: wednesday) }!
        XCTAssertEqual(recap.focusMinutesByDay[index], 75)
        XCTAssertNil(recap.ritualRate)
        XCTAssertNil(recap.busiestHour)
    }
    func testRitualRateCountsOnlyDaysSoFar() {
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: wednesday)!.start
        let elapsed = calendar.dateComponents([.day], from: weekStart, to: calendar.startOfDay(for: wednesday)).day! + 1
        let doneEveryDay = Habit(title: "a", icon: "drop", accentColor: "E0904A",
                                 completedDates: (0..<elapsed).map { calendar.date(byAdding: .day, value: $0, to: weekStart)! })
        let never = Habit(title: "b", icon: "drop", accentColor: "E0904A")
        let recap = WeekRecapBuilder.build(containing: wednesday, now: wednesday, events: [], habits: [doneEveryDay, never], focusSessions: [], calendar: calendar)
        XCTAssertEqual(recap.ritualRate ?? 0, 0.5, accuracy: 0.0001)
    }
    func testBusiestHourIsWhereEventsPileUp() {
        let events = (0..<3).map { offset in
            CalendarEvent(id: "e\(offset)", title: "e", startDate: day(offset - 1, 14), endDate: day(offset - 1, 15.5), calendarName: "x", accentColor: "5B74D6")
        }
        let recap = WeekRecapBuilder.build(containing: wednesday, now: wednesday, events: events, habits: [], focusSessions: [], calendar: calendar)
        XCTAssertEqual(recap.busiestHour, 14)
    }
    func testSentencePicksTheStrongestSignal() {
        XCTAssertEqual(WeekRecapBuilder.sentence(focusMinutes: 150, ritualRate: 0.9, eventCount: 5), String(localized: "A steady week: rituals kept and real focus."))
        XCTAssertEqual(WeekRecapBuilder.sentence(focusMinutes: 400, ritualRate: 0.2, eventCount: 5), String(localized: "A deep week — over \(6) hours of focus."))
        XCTAssertEqual(WeekRecapBuilder.sentence(focusMinutes: 0, ritualRate: 0.85, eventCount: 5), String(localized: "You kept almost every ritual this week."))
        XCTAssertEqual(WeekRecapBuilder.sentence(focusMinutes: 0, ritualRate: nil, eventCount: 25), String(localized: "A full week. Leave a little room for yourself."))
        XCTAssertEqual(WeekRecapBuilder.sentence(focusMinutes: 0, ritualRate: nil, eventCount: 0), String(localized: "A gentle week. One small ritual is enough to begin."))
    }
    func testRitualHistoryGridEndsTodayAndMarksTheFuture() {
        let habit = Habit(title: "a", icon: "drop", accentColor: "E0904A", completedDates: [calendar.startOfDay(for: wednesday)])
        let grid = RitualHistoryBuilder.grid(for: habit, endingOn: wednesday, weeks: 12, calendar: calendar)
        XCTAssertEqual(grid.count, 12)
        XCTAssertTrue(grid.allSatisfy { $0.count == 7 })
        let last = grid[11]
        let todayIndex = (calendar.component(.weekday, from: wednesday) - calendar.firstWeekday + 7) % 7
        XCTAssertEqual(last[todayIndex], true)
        if todayIndex < 6 { XCTAssertNil(last[todayIndex + 1]) }
        XCTAssertEqual(grid[0][0], false)
    }
}
