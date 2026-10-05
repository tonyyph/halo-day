import XCTest

final class HaloDayUITests: XCTestCase {
    @MainActor
    func testVietnameseLocalization() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(vi)", "-AppleLocale", "vi_VN"]
        app.launch()
        if app.buttons["Bắt đầu"].waitForExistence(timeout: 5) {
            XCTAssertTrue(app.staticTexts["Ngày của bạn, đẹp trong từng khoảnh khắc."].exists)
        } else {
            XCTAssertTrue(app.tabBars.buttons["Hôm nay"].waitForExistence(timeout: 5))
        }
    }
    @MainActor
    func testPaywallRendersPlanPlaceholders() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        finishOnboardingIfNeeded(app)
        app.tabBars.buttons["Today"].tap()
        app.buttons["Settings"].tap()
        app.buttons["Upgrade to Premium"].tap()
        XCTAssertTrue(app.staticTexts["Make every glance beautiful."].waitForExistence(timeout: 5))
        for _ in 0..<4 where !app.staticTexts["Yearly"].exists {
            app.scrollViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(app.staticTexts["Yearly"].exists)
        XCTAssertTrue(app.staticTexts["Monthly"].exists)
        XCTAssertTrue(app.staticTexts["Lifetime"].exists)
        XCTAssertTrue(app.buttons["Restore Purchase"].exists)
        XCTAssertTrue(app.buttons["Close"].exists)
        capture(app, "Paywall")
    }
    @MainActor
    func testOnboardingStudioCalendarRitualsAndFocus() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        finishOnboardingIfNeeded(app)
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["DAY PROGRESS"].exists)
        capture(app, "Today")
        app.tabBars.buttons["Calendar"].tap()
        XCTAssertTrue(app.buttons["Month"].waitForExistence(timeout: 3))
        app.buttons["Month"].tap()
        capture(app, "Calendar")
        app.tabBars.buttons["Studio"].tap()
        XCTAssertTrue(app.staticTexts["Widget Studio"].waitForExistence(timeout: 3))
        capture(app, "Studio")
        app.tabBars.buttons["Rituals"].tap()
        XCTAssertTrue(app.staticTexts["Rituals, kept gently"].waitForExistence(timeout: 3))
        let complete = app.buttons["Complete Drink water"]
        XCTAssertTrue(complete.exists); complete.tap()
        capture(app, "Rituals")
        app.tabBars.buttons["Focus"].tap()
        if app.buttons["Begin focus"].exists { app.buttons["Begin focus"].tap() }
        XCTAssertTrue(app.buttons["Pause"].waitForExistence(timeout: 3))
        app.buttons["Pause"].tap()
        XCTAssertTrue(app.buttons["Resume"].waitForExistence(timeout: 3))
        app.buttons["Resume"].tap()
        capture(app, "Focus")
        app.buttons["End"].tap()
        app.buttons["End session"].tap()
        XCTAssertTrue(app.buttons["Begin focus"].waitForExistence(timeout: 3))
    }
    @MainActor private func finishOnboardingIfNeeded(_ app: XCUIApplication) {
        if app.buttons["Begin"].waitForExistence(timeout: 5) {
            app.buttons["Begin"].tap()
            app.buttons["onboarding-primary"].tap()
            app.buttons["onboarding-primary"].tap()
            app.buttons["Not now"].tap()
            app.buttons["Not now"].tap()
            app.buttons["Save my Halo"].tap()
            if app.buttons["Done"].waitForExistence(timeout: 5) { app.buttons["Done"].tap() }
        }
    }
    @MainActor private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways
        add(attachment)
    }
}
