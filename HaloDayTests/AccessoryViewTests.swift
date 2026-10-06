import XCTest
import SwiftUI
@testable import HaloDay

@MainActor
final class AccessoryViewTests: XCTestCase {
    private let calendar = Calendar.current
    private var day: Date { calendar.date(from: DateComponents(year: 2026, month: 10, day: 5))! }
    private func at(_ hour: Double) -> Date { day.addingTimeInterval(hour * 3600) }
    private func event(_ id: String, _ start: Double, _ end: Double, allDay: Bool = false) -> CalendarEvent {
        CalendarEvent(id: id, title: id, startDate: at(start), endDate: at(end), calendarName: "x", accentColor: "5B74D6", isAllDay: allDay)
    }
    private var data: WidgetData {
        WidgetData(date: at(10.75), events: [event("standup", 9, 9.5), event("review", 10.5, 11.25), event("lunch", 13, 14), event("all", 0, 24, allDay: true)],
                   habits: MockData.habits, focus: nil, countdown: Countdown(title: "Lisbon", targetDate: at(24 * 12)), isSample: false)
    }

    func testNextEventPrefersTheOneHappeningNow() {
        XCTAssertEqual(data.nextEvent?.id, "review")
        XCTAssertEqual(data.upcoming(limit: 3).map(\.id), ["review", "lunch"])
    }
    func testMonthProgressAndCountdown() {
        let month = data.monthProgress
        XCTAssertEqual(month.day, 5)
        XCTAssertEqual(month.daysInMonth, 31)
        XCTAssertEqual(month.daysLeft, 26)
        XCTAssertEqual(month.fraction, 5.0 / 31, accuracy: 0.0001)
        XCTAssertEqual(data.countdownDays, 12)
    }
    func testEveryKindRendersInEveryFamilyItSupports() throws {
        for kind in WidgetKind.allCases {
            for family in kind.families {
                for tint in [nil, Color.orange] as [Color?] {
                    let size: CGSize = switch family {
                    case .inline: CGSize(width: 240, height: 20)
                    case .circular: CGSize(width: 64, height: 64)
                    case .rectangular: CGSize(width: 160, height: 72)
                    }
                    let renderer = ImageRenderer(content: AccessoryView(kind: kind, family: family, data: data, tint: tint)
                        .frame(width: size.width, height: size.height).environment(\.colorScheme, .dark))
                    renderer.scale = 2
                    let image = try XCTUnwrap(renderer.cgImage, "\(kind) \(family)")
                    XCTAssertTrue(visible(image), "\(kind) \(family) rendered nothing")
                }
            }
        }
    }
    private func visible(_ image: CGImage) -> Bool {
        let width = image.width, height = image.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let context = CGContext(data: &bytes, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return stride(from: 3, to: bytes.count, by: 4).contains { bytes[$0] > 0 }
    }
}
