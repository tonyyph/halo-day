import XCTest
import SwiftUI
@testable import HaloDay

/// Renders every widget kind × family (and the Live Activity) to PNG attachments for visual review.
@MainActor
final class WidgetGalleryTests: XCTestCase {
    private let calendar = Calendar.current
    private var day: Date { calendar.date(from: DateComponents(year: 2026, month: 10, day: 5))! }
    private let hanoi = GeoCoordinate(latitude: 21.03, longitude: 105.85)

    private func data(_ hour: Double, empty: Bool = false) -> WidgetData {
        let date = day.addingTimeInterval(hour * 3600)
        return WidgetData(date: date, events: empty ? [] : MockData.events(on: day), habits: empty ? [] : MockData.habits,
                          focus: nil, countdown: empty ? nil : Countdown(title: "Lisbon", targetDate: date.addingTimeInterval(12 * 86400)),
                          isSample: !empty)
    }
    private var skies: [(String, SkyID, Double)] { [("living", .livingSky, 10.08), ("celestial", .celestial, 22.5)] }

    func testHomeWidgetsRenderOnEverySky() throws {
        for (name, skyID, hour) in skies {
            for empty in [false, true] {
                let widgetData = data(hour, empty: empty)
                let sky = SkyEngine.state(sky: skyID, at: widgetData.date, coordinate: hanoi)
                for kind in WidgetKind.allCases {
                    for family in kind.homeFamilies {
                        let view = ZStack {
                            SkyBackground(state: sky)
                            HomeWidgetView(kind: kind, family: family, data: widgetData, sky: sky, style: skyID.orbitStyle, coordinate: hanoi,
                                           locked: kind.isPremium && empty).padding(16)
                        }
                        .frame(width: family.size.width, height: family.size.height)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        try attach(view, name: "widget-\(kind.rawValue)-\(family.rawValue)-\(name)\(empty ? "-empty" : "")")
                    }
                }
            }
        }
    }

    func testLockScreenWidgetsRenderVibrant() throws {
        for empty in [false, true] {
            for kind in WidgetKind.allCases {
                for family in kind.families {
                    let size: CGSize = switch family {
                    case .inline: CGSize(width: 260, height: 24)
                    case .circular: CGSize(width: 72, height: 72)
                    case .rectangular: CGSize(width: 158, height: 72)
                    }
                    let view = AccessoryView(kind: kind, family: family, data: data(10.08, empty: empty), tint: nil)
                        .frame(width: size.width, height: size.height)
                        .padding(8)
                        .background(Color(white: 0.18))
                        .environment(\.colorScheme, .dark)
                    try attach(view, name: "lock-\(kind.rawValue)-\(family.rawValue)\(empty ? "-empty" : "")")
                }
            }
        }
    }

    func testLiveActivityRendersEveryState() throws {
        let start = day.addingTimeInterval(10 * 3600)
        let focus = HaloActivityAttributes(title: "Write the Q4 proposal", startDate: start, endDate: start.addingTimeInterval(1500), themeId: SkyID.livingSky.rawValue, accentColor: "D4AF6A")
        let event = HaloActivityAttributes(title: "Design review", startDate: start, endDate: start.addingTimeInterval(1500), themeId: SkyID.celestial.rawValue, accentColor: "5B74D6", isEvent: true)
        let states: [(String, HaloActivityAttributes, HaloActivityAttributes.ContentState)] = [
            ("running", focus, .init(endDate: start.addingTimeInterval(1500), phase: "running")),
            ("paused", focus, .init(endDate: start.addingTimeInterval(1500), pausedRemaining: 900, phase: "paused")),
            ("finished", focus, .init(endDate: start.addingTimeInterval(1500), phase: "finished")),
            ("event", event, .init(endDate: start.addingTimeInterval(1500), phase: "countdown"))
        ]
        for (name, attributes, state) in states {
            let view = FocusActivityView(attributes: attributes, state: state, now: start.addingTimeInterval(600))
                .frame(width: 364)
            try attach(view, name: "activity-\(name)")
        }
    }

    func attach(_ view: some View, name: String) throws {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3
        let image = try XCTUnwrap(renderer.uiImage, name)
        let cg = try XCTUnwrap(image.cgImage)
        XCTAssertGreaterThan(cg.width, 0, name)
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
