import XCTest

final class HaloDayUITests: XCTestCase {
    private let skies = [(theme: "pearlHalo", name: "LivingSky"), (theme: "midnightGold", name: "Celestial"), (theme: "ivoryMinimal", name: "Instrument")]
    private let languages = [(code: "en", locale: "en_US"), (code: "vi", locale: "vi_VN")]

    @MainActor
    func testVietnameseLocalization() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(vi)", "-AppleLocale", "vi_VN"]
        app.launch()
        if app.buttons["Bắt đầu"].waitForExistence(timeout: 5) {
            XCTAssertTrue(app.staticTexts["Ngày của bạn, đẹp trong từng khoảnh khắc."].exists)
        } else {
            XCTAssertTrue(app.tabBars.buttons["Ngày"].waitForExistence(timeout: 5))
        }
    }

    @MainActor
    func testDayRitualEventAndFocusJourney() throws {
        let app = launchFixture(theme: "pearlHalo", screen: "day", language: ("en", "en_US"))
        XCTAssertTrue(app.buttons["orbit-now"].waitForExistence(timeout: 10))

        let bead = app.buttons["bead-10000000-0000-0000-0000-000000000003"]
        XCTAssertTrue(bead.exists)
        XCTAssertEqual(bead.value as? String, "Not done")
        bead.tap()
        XCTAssertEqual(bead.value as? String, "Done")

        let review = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'arc-' AND label CONTAINS 'Design review'")).firstMatch
        XCTAssertTrue(review.exists)
        review.tap()
        XCTAssertTrue(app.buttons["Count down on Lock Screen"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()

        app.buttons["orbit-now"].tap()
        XCTAssertTrue(app.buttons["focus-start"].waitForExistence(timeout: 5))
        app.buttons["focus-start"].tap()
        let pause = app.buttons["focus-pause"]
        XCTAssertTrue(pause.waitForExistence(timeout: 5))
        pause.tap()
        XCTAssertEqual(pause.label, "Resume")
        app.buttons["focus-end"].tap()
        XCTAssertTrue(app.buttons["orbit-now"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testOrbitNowOffCentreOpensFocus() throws {
        let app = launchFixture(theme: "pearlHalo", screen: "day", language: ("en", "en_US"))
        let now = app.descendants(matching: .any)["orbit-now"]
        XCTAssertTrue(now.waitForExistence(timeout: 10))
        for dx in [10.0, -10.0] {
            now.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).withOffset(CGVector(dx: dx, dy: 0)).tap()
            XCTAssertTrue(app.buttons["focus-close"].waitForExistence(timeout: 5), "offset \(dx)")
            app.buttons["focus-close"].tap()
            XCTAssertTrue(now.waitForExistence(timeout: 5))
        }
    }

    @MainActor
    func testMinimizedFocusStaysMinimizedAcrossTabs() throws {
        let app = launchFixture(theme: "pearlHalo", screen: "focus", language: ("en", "en_US"))
        XCTAssertTrue(app.buttons["focus-start"].waitForExistence(timeout: 10))
        app.buttons["focus-start"].tap()
        XCTAssertTrue(app.buttons["focus-minimize"].waitForExistence(timeout: 5))
        app.buttons["focus-minimize"].tap()
        tabButton(app, 1, language: "en").tap()
        tabButton(app, 0, language: "en").tap()
        XCTAssertTrue(app.buttons["column-focus"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["focus-minimize"].exists)
    }

    @MainActor
    func testFocusSetupFitsAtTheLargestTextSize() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestScreenshotMode", "-UITestTheme", "pearlHalo", "-UITestScreen", "focus", "-UITestTime", "10:05",
                               "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        let start = app.buttons["focus-start"]
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        for _ in 0..<4 where !start.isHittable { app.swipeUp() }
        XCTAssertTrue(start.isHittable)
    }

    @MainActor
    func testZoomWeekMonthAndBack() throws {
        let app = launchFixture(theme: "pearlHalo", screen: "day", language: ("en", "en_US"))
        XCTAssertTrue(app.buttons["zoom-week"].waitForExistence(timeout: 10))
        app.buttons["zoom-week"].tap()
        XCTAssertTrue(app.buttons["week-day-2026-10-07"].waitForExistence(timeout: 5))
        app.buttons["zoom-month"].tap()
        let target = app.buttons["month-day-2026-10-20"]
        XCTAssertTrue(target.waitForExistence(timeout: 5))
        target.tap()
        target.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'October 20'")).firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Today"].exists)
        app.buttons["Today"].tap()
        XCTAssertTrue(app.buttons["orbit-now"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testMonthGridScrollsToTheAgenda() throws {
        let app = launchFixture(theme: "pearlHalo", screen: "month", language: ("en", "en_US"))
        let grid = app.descendants(matching: .any)["month-grid"]
        XCTAssertTrue(grid.waitForExistence(timeout: 10))
        let dinner = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'column-' AND label CONTAINS 'Dinner'")).firstMatch
        XCTAssertFalse(dinner.isHittable)
        grid.swipeUp()
        XCTAssertTrue(dinner.isHittable)
    }

    @MainActor
    func testWeekPagesForward() throws {
        let app = launchFixture(theme: "pearlHalo", screen: "week", language: ("en", "en_US"))
        XCTAssertTrue(app.buttons["week-day-2026-10-05"].waitForExistence(timeout: 10))
        app.buttons["week-next"].tap()
        XCTAssertTrue(app.buttons["week-day-2026-10-12"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testSettingsLetYouChooseCalendars() throws {
        let app = launchFixture(theme: "pearlHalo", screen: "you", language: ("en", "en_US"))
        XCTAssertTrue(app.buttons["settings-open"].waitForExistence(timeout: 10))
        app.buttons["settings-open"].tap()
        let row = app.buttons["settings-calendars"]
        for _ in 0..<4 where !row.exists { app.swipeUp() }
        XCTAssertTrue(row.exists)
        row.tap()
        XCTAssertTrue(app.navigationBars["Calendars"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testDayScreenshotMatrix() throws {
        for sky in skies {
            for language in languages {
                for time in ["06:10", "10:05", "18:20", "22:30"] {
                    let app = launchFixture(theme: sky.theme, screen: "day", time: time, language: language)
                    XCTAssertTrue(app.buttons["orbit-now"].waitForExistence(timeout: 10))
                    capture(app, "\(language.code)-\(sky.name)-\(time.replacingOccurrences(of: ":", with: ""))-Day")
                    if time == "10:05" {
                        app.buttons["zoom-week"].tap()
                        XCTAssertTrue(app.buttons["week-day-2026-10-05"].waitForExistence(timeout: 5))
                        capture(app, "\(language.code)-\(sky.name)-1005-Week")
                        app.buttons["zoom-month"].tap()
                        XCTAssertTrue(app.buttons["month-day-2026-10-05"].waitForExistence(timeout: 5))
                        capture(app, "\(language.code)-\(sky.name)-1005-Month")
                    }
                    app.terminate()
                }
            }
        }
        for language in languages {
            let focus = launchFixture(theme: "pearlHalo", screen: "focus", language: language)
            XCTAssertTrue(focus.buttons["focus-start"].waitForExistence(timeout: 10))
            capture(focus, "\(language.code)-LivingSky-1005-Focus")
            focus.terminate()

            let day = launchFixture(theme: "pearlHalo", screen: "day", language: language)
            XCTAssertTrue(day.buttons["orbit-now"].waitForExistence(timeout: 10))
            day.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'arc-' AND label CONTAINS[c] %@", language.code == "vi" ? "thiết kế" : "Design review")).firstMatch.tap()
            XCTAssertTrue(day.buttons[language.code == "vi" ? "Đếm ngược trên Màn khóa" : "Count down on Lock Screen"].waitForExistence(timeout: 5))
            capture(day, "\(language.code)-LivingSky-1005-Event")
            day.terminate()
        }
    }

    @MainActor
    func testOnboardingThenEveryTab() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        finishOnboardingIfNeeded(app)
        XCTAssertTrue(app.buttons["orbit-now"].waitForExistence(timeout: 8))
        app.buttons["zoom-month"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["month-grid"].waitForExistence(timeout: 5))
        tabButton(app, 1, language: "en").tap()
        XCTAssertTrue(app.staticTexts["Widget Studio"].waitForExistence(timeout: 3))
        tabButton(app, 2, language: "en").tap()
        XCTAssertTrue(app.buttons["ritual-new"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testRecordOnboardingMotion() throws {
        let app = launchFixture(theme: "pearlHalo", screen: "onboarding", language: ("en", "en_US"))
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
        let app = launchFixture(theme: "pearlHalo", screen: "studio", language: ("en", "en_US"))
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
        let app = launchFixture(theme: "emeraldRitual", screen: "day", language: ("en", "en_US"))
        let finalBead = app.buttons["bead-10000000-0000-0000-0000-000000000003"]
        XCTAssertTrue(finalBead.waitForExistence(timeout: 10))
        XCTAssertEqual(finalBead.value as? String, "Not done")
        finalBead.tap()
        XCTAssertEqual(finalBead.value as? String, "Done")
    }

    @MainActor
    func testEditRitualTimeAndSeeTheFreeLimit() throws {
        let app = launchFixture(theme: "pearlHalo", screen: "you", language: ("en", "en_US"))
        let row = app.buttons["ritual-row-10000000-0000-0000-0000-000000000003"]
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.tap()
        XCTAssertTrue(app.buttons["ritual-edit"].waitForExistence(timeout: 5))
        app.buttons["ritual-edit"].tap()
        XCTAssertTrue(app.buttons["time-morning"].waitForExistence(timeout: 5))
        app.buttons["time-morning"].tap()
        app.buttons["ritual-save"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Morning'")).firstMatch.waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        app.buttons["ritual-new"].tap()
        XCTAssertTrue(app.buttons["ritual-limit"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testAddCountdownAndPickASky() throws {
        let app = launchFixture(theme: "pearlHalo", screen: "you", language: ("en", "en_US"))
        let add = app.buttons["countdown-new"]
        XCTAssertTrue(add.waitForExistence(timeout: 10))
        for _ in 0..<4 where !add.isHittable { app.swipeUp() }
        add.tap()
        let name = app.textFields["countdown-name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap(); name.typeText("Lisbon")
        app.buttons["countdown-save"].tap()
        XCTAssertTrue(app.staticTexts["Lisbon"].waitForExistence(timeout: 5))
        for _ in 0..<4 where !app.buttons["settings-open"].isHittable { app.swipeDown() }
        app.buttons["settings-open"].tap()
        let sky = app.buttons["settings-sky"]
        XCTAssertTrue(sky.waitForExistence(timeout: 5))
        sky.tap()
        let celestial = app.buttons["sky-celestial"]
        XCTAssertTrue(celestial.waitForExistence(timeout: 5))
        celestial.tap()
        XCTAssertTrue(celestial.isSelected)
    }

    @MainActor
    func testPaywallRendersPlanPlaceholders() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        finishOnboardingIfNeeded(app)
        tabButton(app, 2, language: "en").tap()
        app.buttons["settings-open"].tap()
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

    @MainActor private func launchFixture(theme: String, screen: String, time: String = "10:05", language: (String, String)) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-UITestScreenshotMode", "-UITestTheme", theme, "-UITestScreen", screen, "-UITestTime", time,
            "-AppleLanguages", "(\(language.0))", "-AppleLocale", language.1
        ]
        app.launch()
        return app
    }

    @MainActor private func tabButton(_ app: XCUIApplication, _ tab: Int, language: String) -> XCUIElement {
        let english = ["Day", "Studio", "You"]
        let vietnamese = ["Ngày", "Studio", "Bạn"]
        return app.tabBars.buttons[(language == "vi" ? vietnamese : english)[tab]]
    }

    @MainActor private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways
        add(attachment)
    }
}
