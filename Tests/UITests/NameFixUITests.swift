import XCTest
@MainActor final class NameFixUITests: XCTestCase {
    func testEmptyStateShowsOnlyInputAndSettingsOpens() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--skip-onboarding"]
        app.launch()
        XCTAssertTrue(app.buttons["addFiles"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["addFolders"].exists)
        // Result controls do not exist until something has been added.
        XCTAssertFalse(app.buttons["rename"].exists)
        XCTAssertFalse(app.textFields["search"].exists)
        app.buttons["settings"].click()
        XCTAssertTrue(app.buttons["theme-olive"].waitForExistence(timeout: 3))
    }
}
