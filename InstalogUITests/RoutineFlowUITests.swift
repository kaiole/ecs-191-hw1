import XCTest

/// Drives the core loop through accessibility elements only (no swipes), covering AT-35.
/// Set SCREENSHOT_DIR to also write PNGs to disk.
@MainActor
final class RoutineFlowUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--reset-data"]
        app.launch()
    }

    private func snapshot(_ name: String) {
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if let directory = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] {
            try? shot.pngRepresentation.write(to: URL(fileURLWithPath: directory).appendingPathComponent("\(name).png"))
        }
    }

    private func loadDemo() {
        let demo = app.buttons["Load demo routine"]
        XCTAssertTrue(demo.waitForExistence(timeout: 10))
        demo.tap()
        XCTAssertTrue(logButton.waitForExistence(timeout: 10))
        XCTAssertTrue(logButton.label.hasPrefix("Log to Breakfast"))
    }

    private var logButton: XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Log '")).firstMatch
    }

    func testEmptyStateThenRoutineLogging() {
        snapshot("01-empty")
        loadDemo()
        snapshot("02-start-of-day")

        // Adjust one quantity for this log only.
        let more = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'More '")).firstMatch
        XCTAssertTrue(more.exists)
        more.tap()
        XCTAssertTrue(app.buttons["Reset"].waitForExistence(timeout: 3))
        snapshot("03-adjusted")

        logButton.tap()
        XCTAssertTrue(app.buttons["Undo"].waitForExistence(timeout: 5))
        snapshot("04-logged")
        XCTAssertFalse(app.buttons["Reset"].exists, "Draft returns to saved defaults after logging")
        XCTAssertTrue(logButton.label.hasPrefix("Log again to Breakfast"))

        // Select another meal by its chip and log it too.
        app.buttons["Greek yogurt bowl"].tap()
        logButton.tap()
        let summary = app.buttons.matching(NSPredicate(format: "label BEGINSWITH '2 logged here'")).firstMatch
        XCTAssertTrue(summary.waitForExistence(timeout: 5))
        summary.tap()
        snapshot("05-entries-expanded")

        // Open an entry and use Delete with confirmation, then Undo.
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Greek yogurt bowl, logged'")).firstMatch.tap()
        XCTAssertTrue(app.buttons["Delete…"].waitForExistence(timeout: 3))
        snapshot("06-entry-sheet")
        app.buttons["Delete…"].tap()
        app.buttons["Delete entry"].tap()
        XCTAssertTrue(app.buttons["Undo"].waitForExistence(timeout: 5))
        app.buttons["Undo"].tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH '2 logged here'")).firstMatch.waitForExistence(timeout: 5))

        // Browse sections with the buttons; wraps from first to last.
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Previous section'")).firstMatch.tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Dinner, section 4'")).firstMatch.waitForExistence(timeout: 3))
        snapshot("07-dinner-all-meals")

        // Sections sheet.
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Dinner, section'")).firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Here now"].waitForExistence(timeout: 3))
        snapshot("08-sections-sheet")
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Breakfast. 2 logged'")).firstMatch.tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Breakfast, section 1'")).firstMatch.waitForExistence(timeout: 3))
    }

    func testAddFoodSearchAndCustomPortion() {
        loadDemo()
        app.buttons["Add food"].tap()
        XCTAssertTrue(app.staticTexts["Add food"].waitForExistence(timeout: 3))
        snapshot("09-add-saved")
        app.buttons["Foods"].tap()
        let search = app.textFields["Search foods"]
        XCTAssertTrue(search.waitForExistence(timeout: 3))
        search.tap()
        search.typeText("banana")
        let banana = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Bananas, raw'")).firstMatch
        XCTAssertTrue(banana.waitForExistence(timeout: 5))
        snapshot("10-search")
        banana.tap()
        let add = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Add to this entry'")).firstMatch
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        snapshot("11-food-detail")
        add.tap()
        let logTo = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Log to Breakfast'")).firstMatch
        XCTAssertTrue(logTo.waitForExistence(timeout: 3))
        snapshot("12-plate")
        logTo.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Added Bananas, raw to Breakfast'")).firstMatch.waitForExistence(timeout: 5))
        snapshot("13-added")
    }

    func testSettingsAndNutrients() {
        loadDemo()
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.staticTexts["Auto-advance after logging"].waitForExistence(timeout: 3))
        snapshot("14-settings")
        app.buttons["Order sections and assign meals"].tap()
        XCTAssertTrue(app.navigationBars["Sections & meals"].waitForExistence(timeout: 3))
        snapshot("15-setup")
        app.buttons.matching(NSPredicate(format: "label CONTAINS 'Lunch'")).firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Opens first"].waitForExistence(timeout: 3))
        snapshot("15b-section-meals")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons.matching(NSPredicate(format: "label CONTAINS 'Saved meals'")).firstMatch.tap()
        app.buttons.matching(NSPredicate(format: "label CONTAINS 'Overnight oats'")).firstMatch.tap()
        let more = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'More '")).firstMatch
        XCTAssertTrue(more.waitForExistence(timeout: 3))
        more.tap()
        snapshot("15c-meal-editor")
        app.navigationBars.buttons["Save"].tap()
        XCTAssertTrue(app.navigationBars["Saved meals"].waitForExistence(timeout: 3))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["Close"].firstMatch.tap()

        logButton.tap()
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Consumed'")).firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Nutrients"].waitForExistence(timeout: 3))
        snapshot("16-nutrients")
    }
}
