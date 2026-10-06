import XCTest
import SwiftUI
@testable import HaloDay

@MainActor
final class OrbitRenderTests: XCTestCase {
    private func sky(_ id: SkyID, hour: Int) -> SkyState {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh")!
        let date = calendar.date(from: DateComponents(year: 2026, month: 10, day: 5, hour: hour))!
        return SkyEngine.state(sky: id, at: date, coordinate: GeoCoordinate(latitude: 21.03, longitude: 105.85), calendar: calendar)
    }
    private func content() -> OrbitContent {
        let day = Calendar.current.startOfDay(for: .now)
        return OrbitContent(layout: OrbitLayout(day: day, events: MockData.events(on: day)),
                            beads: [OrbitBead(id: UUID(), hour: 7, isDone: true, colorHex: "E0904A")],
                            focusSpans: [8...8.5], nightSpans: [0...5.8, 17.6...24], nowHour: 10.1)
    }
    func testOrbitRendersForEveryStyleAndSize() throws {
        for (id, hour) in [(SkyID.livingSky, 10), (.livingSky, 23), (.instrument, 10), (.mist, 10)] {
            for size in [44.0, 160.0, 320.0] {
                let renderer = ImageRenderer(content: OrbitCanvas(content: content(), sky: sky(id, hour: hour), style: id.orbitStyle).frame(width: size, height: size))
                renderer.scale = 2
                let image = try XCTUnwrap(renderer.cgImage, "\(id) \(size)")
                XCTAssertEqual(image.width, Int(size * 2))
                XCTAssertTrue(hasVisiblePixels(image), "\(id) \(size) rendered nothing")
            }
        }
    }
    func testSkyBackgroundRenders() throws {
        let renderer = ImageRenderer(content: SkyBackground(state: sky(.livingSky, hour: 18)).frame(width: 120, height: 240))
        XCTAssertTrue(hasVisiblePixels(try XCTUnwrap(renderer.cgImage)))
    }
    private func hasVisiblePixels(_ image: CGImage) -> Bool {
        let width = image.width, height = image.height
        var data = [UInt8](repeating: 0, count: width * height * 4)
        let context = CGContext(data: &data, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return stride(from: 3, to: data.count, by: 4).contains { data[$0] > 0 }
    }
}
