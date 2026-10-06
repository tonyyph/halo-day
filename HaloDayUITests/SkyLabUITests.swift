import XCTest

final class SkyLabUITests: XCTestCase {
    @MainActor
    func testSkyLabAcrossTheDay() throws {
        let cases: [(minutes: Int, sky: String, language: String)] = [
            (370, "livingSky", "vi"), (605, "livingSky", "vi"), (1100, "livingSky", "vi"), (1350, "livingSky", "vi"),
            (605, "instrument", "en"), (605, "mist", "en"), (1350, "aurora", "en"), (1080, "goldenHour", "en")
        ]
        for item in cases {
            let app = XCUIApplication()
            app.launchArguments += ["-SkyLab", "-SkyLabMinutes", "\(item.minutes)", "-SkyLabSky", item.sky, "-SkyLabPlace", "hanoi",
                                    "-AppleLanguages", "(\(item.language))", "-AppleLocale", item.language == "vi" ? "vi_VN" : "en_US"]
            app.launch()
            XCTAssertTrue(app.descendants(matching: .any)["skylab-root"].waitForExistence(timeout: 10))
            XCTAssertTrue(app.staticTexts["skylab-moment"].exists)
            let shot = XCTAttachment(screenshot: app.screenshot())
            shot.name = "SkyLab-\(item.sky)-\(item.minutes)-\(item.language)"
            shot.lifetime = .keepAlways
            add(shot)
            app.terminate()
        }
    }
}
