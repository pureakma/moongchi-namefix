import XCTest
@MainActor final class NameFixUITests: XCTestCase {
    func testInitialWorkspaceAndSettings() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["addFiles"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["addFolders"].exists)
        XCTAssertFalse(app.buttons["rename"].isEnabled)
        app.buttons["settings"].click()
        XCTAssertTrue(app.buttons["theme-olive"].waitForExistence(timeout: 3))
    }
}
