import XCTest

final class PrenommeUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // Skip onboarding so we land directly on the TabView
        app.launchArguments = ["--skip-onboarding"]
        app.launch()
    }

    func testTabBarVisible() {
        XCTAssertTrue(app.tabBars.firstMatch.exists)
    }

    func testDiscoverTabShowsNames() {
        app.tabBars.buttons["Découvrir"].tap()
        // HomeView uses a NavigationStack with title "Prénomme"
        let title = app.navigationBars["Prénomme"].firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 5))
    }

    func testFavoritesTabShowsEmptyState() {
        app.tabBars.buttons["Favoris"].tap()
        XCTAssertTrue(
            app.staticTexts["Aucun favori"].waitForExistence(timeout: 3)
        )
    }
}
