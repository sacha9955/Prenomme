import XCTest

final class PrenommeUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    func testTabBarVisible() {
        XCTAssertTrue(app.tabBars.firstMatch.exists)
    }

    func testDiscoverTabShowsNames() {
        app.tabBars.buttons["Découvrir"].tap()
        let list = app.collectionViews.firstMatch
        XCTAssertTrue(list.waitForExistence(timeout: 3))
    }

    func testFavoritesTabShowsEmptyState() {
        app.tabBars.buttons["Favoris"].tap()
        XCTAssertTrue(
            app.staticTexts["Aucun favori"].waitForExistence(timeout: 3)
        )
    }
}
