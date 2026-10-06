import XCTest
@testable import HaloDay

final class OrbitGeometryTests: XCTestCase {
    private var calendar: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh")!; return c }
    private var day: Date { calendar.date(from: DateComponents(year: 2026, month: 10, day: 5))! }
    private func event(_ id: String, _ start: Double, _ end: Double, allDay: Bool = false) -> CalendarEvent {
        CalendarEvent(id: id, title: id, startDate: day.addingTimeInterval(start * 3600), endDate: day.addingTimeInterval(end * 3600),
                      calendarName: "Work", accentColor: "E2607D", isAllDay: allDay)
    }

    func testCardinalHoursSitWhereTheSunDoes() {
        let center = CGPoint(x: 100, y: 100)
        func p(_ h: Double) -> CGPoint { OrbitGeometry.point(forHour: h, radius: 50, center: center) }
        XCTAssertEqual(p(12).x, 100, accuracy: 0.001); XCTAssertEqual(p(12).y, 50, accuracy: 0.001)   // top
        XCTAssertEqual(p(0).y, 150, accuracy: 0.001)                                                  // bottom
        XCTAssertEqual(p(6).x, 50, accuracy: 0.001)                                                   // left
        XCTAssertEqual(p(18).x, 150, accuracy: 0.001)                                                 // right
    }
    func testHourRoundTripsThroughPoints() {
        let center = CGPoint(x: 0, y: 0)
        for hour in stride(from: 0.0, to: 24, by: 0.5) {
            XCTAssertEqual(OrbitGeometry.hour(at: OrbitGeometry.point(forHour: hour, radius: 80, center: center), center: center), hour, accuracy: 0.0001)
        }
    }
    func testOverlappingEventsTakeLanesAndExcessBecomesOverflow() {
        let layout = OrbitLayout(day: day, events: [
            event("a", 9, 11), event("b", 9.5, 10.5), event("c", 10, 12), event("d", 10.2, 10.4), event("e", 10.25, 10.75),
            event("f", 13, 14), event("all", 0, 24, allDay: true)
        ], calendar: calendar)
        XCTAssertEqual(layout.arcs.map(\.id), ["a", "b", "c", "f"])
        XCTAssertEqual(layout.arcs.map(\.lane), [0, 1, 2, 0])
        XCTAssertEqual(layout.overflow, [OrbitOverflow(hour: 10.2, count: 2)])
    }
    func testMidnightCrossingIsClippedAndFlaggedAndTinyEventsStayVisible() {
        let layout = OrbitLayout(day: day, events: [event("late", 23, 26), event("early", -2, 1), event("blip", 15, 15)], calendar: calendar)
        let byID = Dictionary(uniqueKeysWithValues: layout.arcs.map { ($0.id, $0) })
        XCTAssertEqual(byID["late"]?.end, 24); XCTAssertEqual(byID["late"]?.continuesAfter, true)
        XCTAssertEqual(byID["early"]?.start, 0); XCTAssertEqual(byID["early"]?.continuesBefore, true)
        XCTAssertEqual(byID["blip"]!.end - byID["blip"]!.start, 0.25, accuracy: 0.0001)
    }
    func testNightSpansWrapPastMidnightAndHandlePolarDays() {
        let sunrise = day.addingTimeInterval(5.75 * 3600), sunset = day.addingTimeInterval(17.6 * 3600)
        let spans = OrbitGeometry.nightSpans(.normal(sunrise: sunrise, sunset: sunset), calendar: calendar)
        XCTAssertEqual(spans.count, 2)
        XCTAssertEqual(spans[0].lowerBound, 0); XCTAssertEqual(spans[0].upperBound, 5.75, accuracy: 0.001)
        XCTAssertEqual(spans[1].lowerBound, 17.6, accuracy: 0.001); XCTAssertEqual(spans[1].upperBound, 24)
        XCTAssertEqual(OrbitGeometry.nightSpans(.polarNight, calendar: calendar), [0...24])
        XCTAssertEqual(OrbitGeometry.nightSpans(.polarDay, calendar: calendar), [])
    }
    func testHitTestingPrefersNowThenBeadsThenArcs() {
        let metrics = OrbitMetrics(size: 300)
        let layout = OrbitLayout(day: day, events: [event("review", 10.5, 11.25)], calendar: calendar)
        let bead = OrbitBead(id: UUID(), hour: 7, isDone: false, colorHex: "E0904A")
        func at(_ hour: Double, _ radius: CGFloat) -> CGPoint { OrbitGeometry.point(forHour: hour, radius: radius, center: metrics.center) }
        XCTAssertEqual(OrbitGeometry.hitTest(at(10.1, metrics.radius), metrics: metrics, layout: layout, beads: [bead], nowHour: 10.08), .now)
        XCTAssertEqual(OrbitGeometry.hitTest(at(7, metrics.beadRadius), metrics: metrics, layout: layout, beads: [bead], nowHour: 10.08), .bead(bead.id))
        XCTAssertEqual(OrbitGeometry.hitTest(at(10.9, metrics.radius), metrics: metrics, layout: layout, beads: [bead], nowHour: 10.08), .arc("review"))
        XCTAssertNil(OrbitGeometry.hitTest(metrics.center, metrics: metrics, layout: layout, beads: [bead], nowHour: 10.08))
    }
}
