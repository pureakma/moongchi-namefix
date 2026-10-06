import XCTest
@testable import NameFixUIModel

final class WindowLayoutTests: XCTestCase {
    let main = ScreenArea(id: "main", visibleFrame: CGRect(x: 0, y: 40, width: 1440, height: 840))
    func testInitialSizeFitsSmallAndLargeScaledWorkAreas() {
        for area in [CGRect(x: 0, y: 30, width: 800, height: 570), CGRect(x: -1920, y: 50, width: 1920, height: 1030), CGRect(x: 0, y: 0, width: 3840, height: 2100)] {
            let frame = WindowLayout.initial(on: area)
            XCTAssertTrue(area.contains(frame)); XCTAssertLessThanOrEqual(frame.width, 1180); XCTAssertLessThanOrEqual(frame.height, 808)
            XCTAssertEqual(frame.midX, area.midX, accuracy: 0.01); XCTAssertEqual(frame.midY, area.midY, accuracy: 0.01)
        }
    }
    func testRestoresExactLastFrameOnSameDisplay() throws {
        let frame = CGRect(x: 210, y: 150, width: 640, height: 480)
        let saved = WindowPlacement(frame: frame, screenID: main.id, screenFrame: main.visibleFrame)
        XCTAssertEqual(try XCTUnwrap(WindowLayout.restored(saved, screens: [main], preferredID: main.id)), frame)
    }
    func testDisconnectedDisplayAndResolutionChangeKeepWindowReachable() throws {
        let external = ScreenArea(id: "external", visibleFrame: CGRect(x: -2560, y: 0, width: 2560, height: 1400))
        let saved = WindowPlacement(frame: CGRect(x: -2400, y: 90, width: 1900, height: 1200), screenID: external.id, screenFrame: external.visibleFrame)
        let fallback = try XCTUnwrap(WindowLayout.restored(saved, screens: [main], preferredID: main.id))
        XCTAssertTrue(main.visibleFrame.contains(fallback))
        let scaled = ScreenArea(id: external.id, visibleFrame: CGRect(x: 1440, y: 80, width: 1280, height: 720))
        let changed = try XCTUnwrap(WindowLayout.restored(saved, screens: [main, scaled], preferredID: main.id))
        XCTAssertTrue(scaled.visibleFrame.contains(changed))
    }
    func testCorruptOrFuturePlacementFallsBackAndNoDisplayIsSafe() {
        var invalid = WindowPlacement(frame: .zero, screenID: main.id, screenFrame: main.visibleFrame)
        XCTAssertEqual(WindowLayout.restored(invalid, screens: [main], preferredID: nil), WindowLayout.initial(on: main.visibleFrame))
        invalid.frame = CGRect(x: 0, y: 0, width: 500, height: 400); invalid.version = 2
        XCTAssertEqual(WindowLayout.restored(invalid, screens: [main], preferredID: nil), WindowLayout.initial(on: main.visibleFrame))
        XCTAssertNil(WindowLayout.restored(nil, screens: [], preferredID: nil))
    }
    func testResponsiveThresholdsAndSheetsFitParent() {
        XCTAssertFalse(WindowLayout.wide(width: 899)); XCTAssertTrue(WindowLayout.wide(width: 900))
        for available in [CGSize(width: 320, height: 240), CGSize(width: 480, height: 360), CGSize(width: 1180, height: 780)] {
            let sheet = WindowLayout.sheet(preferred: CGSize(width: 840, height: 580), available: available)
            XCTAssertLessThanOrEqual(sheet.width, available.width); XCTAssertLessThanOrEqual(sheet.height, available.height)
        }
    }
    @MainActor func testWindowGeometryPersistsIndependentlyOfAppSettings() throws {
        let suite = "NameFix.WindowTests.\(UUID())", defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("keep", forKey: "unrelatedSetting")
        let saved = WindowPlacement(frame: CGRect(x: 100, y: 130, width: 680, height: 420), screenID: main.id, screenFrame: main.visibleFrame)
        WindowPlacementStore(defaults: defaults).save(saved)
        XCTAssertEqual(WindowPlacementStore(defaults: defaults).load()?.frame, saved.frame)
        XCTAssertEqual(defaults.string(forKey: "unrelatedSetting"), "keep")
        var invalid = saved; invalid.frame = .zero
        WindowPlacementStore(defaults: defaults).save(invalid)
        XCTAssertEqual(WindowPlacementStore(defaults: defaults).load()?.frame, saved.frame)
    }
    func testSidebarFollowsInputAndWindowWidthWithoutAToggle() {
        XCTAssertEqual(WindowLayout.sidebarMode(windowWidth: 1180, hasInput: false), .navigation)
        XCTAssertEqual(WindowLayout.sidebarMode(windowWidth: 1180, hasInput: true), .railWithTree)
        XCTAssertEqual(WindowLayout.sidebarMode(windowWidth: 759, hasInput: false), .hidden)
        XCTAssertEqual(WindowLayout.sidebarMode(windowWidth: 759, hasInput: true), .hidden)
        XCTAssertEqual(WindowLayout.sidebarMode(windowWidth: 760, hasInput: false), .navigation)
    }
    func testNavigationWidthIsFixedAndOnlyTheTreeWidthIsRemembered() {
        let navigation = WindowLayout.sidebarWidths(.navigation, treeWidth: 300)
        XCTAssertEqual(navigation.minimum, navigation.maximum); XCTAssertEqual(navigation.preferred, WindowLayout.navigationWidth)
        let tree = WindowLayout.sidebarWidths(.railWithTree, treeWidth: 300)
        XCTAssertEqual(tree.preferred, WindowLayout.railWidth + 300)
        XCTAssertLessThan(tree.minimum, tree.preferred); XCTAssertGreaterThan(tree.maximum, tree.preferred)
        XCTAssertEqual(WindowLayout.treeWidth(nil), WindowLayout.defaultTreeWidth)
        XCTAssertEqual(WindowLayout.treeWidth(10), WindowLayout.treeWidthRange.lowerBound)
        XCTAssertEqual(WindowLayout.treeWidth(9999), WindowLayout.treeWidthRange.upperBound)
        XCTAssertEqual(WindowLayout.treeWidth(.nan), WindowLayout.defaultTreeWidth)
    }
}
