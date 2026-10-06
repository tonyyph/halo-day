import XCTest
@testable import HaloDay

@MainActor
final class ArtRendererTests: XCTestCase {
    private func sky(_ id: SkyID) -> SkyState {
        SkyEngine.state(sky: id, at: Date(timeIntervalSince1970: 1_791_170_700), coordinate: GeoCoordinate(latitude: 21.03, longitude: 105.85))
    }
    private var scene: DayScene {
        let day = Calendar.current.startOfDay(for: .now)
        return DaySceneBuilder.build(day: day, now: day.addingTimeInterval(10 * 3600), events: MockData.events(on: day), habits: MockData.habits,
                                     focusSessions: [], solar: .normal(sunrise: day.addingTimeInterval(6 * 3600), sunset: day.addingTimeInterval(18 * 3600)))
    }

    func testWallpaperRendersAtPhoneResolution() throws {
        let image = try XCTUnwrap(ArtRenderer.wallpaper(WallpaperArt(sky: sky(.livingSky), orbit: scene.orbit, style: .glow)))
        XCTAssertEqual(image.size.width * image.scale, 1290)
        XCTAssertEqual(image.size.height * image.scale, 2796)
    }
    func testShareCardRendersAtStoryResolution() throws {
        let art = ShareCardArt(scene: scene, sky: sky(.celestial), style: .glow, showTitles: false, events: MockData.events(), isSample: true)
        let image = try XCTUnwrap(ArtRenderer.shareCard(art))
        XCTAssertEqual(image.size.width * image.scale, 1080)
        XCTAssertEqual(image.size.height * image.scale, 1920)
    }
    func testShareCardHidesEventNamesUnlessAsked() {
        let events = MockData.events()
        XCTAssertTrue(ShareCardArt.lines(events: events, showTitles: false).isEmpty)
        let shown = ShareCardArt.lines(events: events, showTitles: true)
        XCTAssertEqual(shown.count, 4)
        XCTAssertTrue(shown[0].contains(events[0].title))
    }
    func testOnlyTwoWallpapersAreFree() {
        XCTAssertTrue(WallpaperMoment.isFree(sky: .livingSky, moment: .dawn))
        XCTAssertTrue(WallpaperMoment.isFree(sky: .celestial, moment: .night))
        XCTAssertFalse(WallpaperMoment.isFree(sky: .livingSky, moment: .night))
        XCTAssertFalse(WallpaperMoment.isFree(sky: .aurora, moment: .dawn))
    }
}
