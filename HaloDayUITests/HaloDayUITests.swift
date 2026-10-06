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
    func testScreenshotMatrix() throws {
        let themes = [
            (id: "pearlHalo", appearance: "light", name: "Pearl"),
            (id: "rubyGlass", appearance: "dark", name: "Ruby"),
            (id: "midnightGold", appearance: "dark", name: "MidnightGold")
        ]
        let languages = [(code: "en", locale: "en_US"), (code: "vi", locale: "vi_VN")]

        for theme in themes {
            for language in languages {
                var app = launchFixture(theme: theme.id, appearance: theme.appearance, screen: "today", language: language)
                XCTAssertTrue(tabButton(app, 0, language: language.code).waitForExistence(timeout: 10))
                capture(app, "\(language.code)-\(theme.name)-Today")
                app.terminate()
                app = launchFixture(theme: theme.id, appearance: theme.appearance, screen: "calendar", language: language)
                XCTAssertTrue(app.descendants(matching: .any)["calendar-month-grid"].waitForExistence(timeout: 10))
                capture(app, "\(language.code)-\(theme.name)-Calendar")
                captureTab(app, 2, language: language.code, name: "\(language.code)-\(theme.name)-Studio")
                captureTab(app, 3, language: language.code, name: "\(language.code)-\(theme.name)-Rituals")
                XCTAssertTrue(app.staticTexts[language.code == "vi" ? "ngày liên tiếp" : "day streak"].exists)
                captureTab(app, 4, language: language.code, name: "\(language.code)-\(theme.name)-Focus")

                tabButton(app, 0, language: language.code).tap()
                app.buttons["settings-open"].tap()
                XCTAssertTrue(app.buttons["settings-theme"].waitForExistence(timeout: 5))
                capture(app, "\(language.code)-\(theme.name)-Settings")
                app.buttons["settings-theme"].tap()
                XCTAssertTrue(app.buttons["theme-pearlHalo"].waitForExistence(timeout: 5))
                capture(app, "\(language.code)-\(theme.name)-Themes")
                app.navigationBars.buttons.element(boundBy: 0).tap()
                app.buttons["settings-upgrade"].tap()
                XCTAssertTrue(app.buttons["paywall-close"].waitForExistence(timeout: 5))
                capture(app, "\(language.code)-\(theme.name)-Paywall")
                app.buttons["paywall-close"].tap()
                app.terminate()

                let onboarding = launchFixture(theme: theme.id, appearance: theme.appearance, screen: "onboarding", language: language)
                XCTAssertTrue(onboarding.buttons["onboarding-primary"].waitForExistence(timeout: 10))
                capture(onboarding, "\(language.code)-\(theme.name)-Onboarding")
                onboarding.terminate()
            }
        }
    }

    @MainActor
    func testRecordOnboardingMotion() throws {
        let app = launchFixture(theme: "pearlHalo", appearance: "light", screen: "onboarding", language: ("en", "en_US"))
        XCTAssertTrue(app.buttons["onboarding-primary"].waitForExistence(timeout: 10))
        app.buttons["onboarding-primary"].tap()
        app.buttons["onboarding-primary"].tap()
        app.buttons["onboarding-primary"].tap()
        app.buttons["Not now"].tap()
        app.buttons["Not now"].tap()
        app.buttons["Save my Halo"].tap()
        if app.buttons["Done"].waitForExistence(timeout: 8) { app.buttons["Done"].tap() }
        XCTAssertTrue(tabButton(app, 0, language: "en").waitForExistence(timeout: 8))
    }

    @MainActor
    func testRecordStudioThemeAndTypeSwitching() throws {
        let app = launchFixture(theme: "pearlHalo", appearance: "light", screen: "studio", language: ("en", "en_US"))
        XCTAssertTrue(app.staticTexts["Widget Studio"].waitForExistence(timeout: 10))
        let ruby = app.buttons["theme-orb-rubyGlass"]
        app.swipeUp()
        XCTAssertTrue(ruby.waitForExistence(timeout: 5))
        ruby.tap()
        let month = app.buttons["chip-month"]
        XCTAssertTrue(month.waitForExistence(timeout: 5))
        month.tap()
        XCTAssertTrue(app.buttons["Save preset"].exists)
    }

    @MainActor
    func testRecordFinalRitualCompletion() throws {
        let app = launchFixture(theme: "emeraldRitual", appearance: "dark", screen: "rituals", language: ("en", "en_US"))
        XCTAssertTrue(app.staticTexts["Rituals, kept gently"].waitForExistence(timeout: 10))
        let finalHabit = app.buttons["habit-check-10000000-0000-0000-0000-000000000003"]
        XCTAssertTrue(finalHabit.waitForExistence(timeout: 5))
        XCTAssertEqual(finalHabit.value as? String, "Not completed")
        finalHabit.tap()
        let celebration = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "All done today"))
            .firstMatch
        XCTAssertTrue(celebration.waitForExistence(timeout: 5))
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
        let month = app.segmentedControls.buttons["Month"]
        XCTAssertTrue(month.waitForExistence(timeout: 3))
        month.tap()
        XCTAssertTrue(app.descendants(matching: .any)["calendar-month-grid"].waitForExistence(timeout: 5))
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

    @MainActor private func launchFixture(
        theme: String,
        appearance: String,
        screen: String,
        language: (String, String)
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-UITestScreenshotMode", "-UITestTheme", theme,
            "-UITestAppearance", appearance, "-UITestScreen", screen,
            "-AppleLanguages", "(\(language.0))", "-AppleLocale", language.1
        ]
        app.launch()
        return app
    }

    @MainActor private func captureTab(_ app: XCUIApplication, _ tab: Int, language: String, name: String) {
        let button = tabButton(app, tab, language: language)
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        button.tap()
        if tab == 1 {
            let month = app.segmentedControls.buttons[language == "vi" ? "Tháng" : "Month"]
            XCTAssertTrue(month.waitForExistence(timeout: 5))
            month.tap()
            XCTAssertTrue(month.isSelected)
            XCTAssertTrue(app.descendants(matching: .any)["calendar-month-grid"].waitForExistence(timeout: 5))
        }
        capture(app, name)
    }

    @MainActor private func tabButton(_ app: XCUIApplication, _ tab: Int, language: String) -> XCUIElement {
        let english = ["Today", "Calendar", "Studio", "Rituals", "Focus"]
        let vietnamese = ["Hôm nay", "Lịch", "Studio", "Thói quen", "Tập trung"]
        return app.tabBars.buttons[(language == "vi" ? vietnamese : english)[tab]]
    }
    @MainActor private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways
        add(attachment)
    }
}
