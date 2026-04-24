import XCTest
@testable import Prenomme

final class SwipeCounterTests: XCTestCase {

    private var suiteName: String!
    private var counter: SwipeCounter!

    override func setUp() {
        super.setUp()
        suiteName = "test.swipe.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        counter = SwipeCounter(defaults: defaults)
    }

    override func tearDown() {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testInitialCountIsZero() {
        XCTAssertEqual(counter.todayCount, 0)
    }

    func testIncrementAdds() {
        counter.increment()
        counter.increment()
        XCTAssertEqual(counter.todayCount, 2)
    }

    func testHasSwipesRemainingBelowLimit() {
        XCTAssertTrue(counter.hasSwipesRemaining)
    }

    func testHasSwipesRemainingAtLimit() {
        for _ in 0..<SwipeCounter.freeLimit {
            counter.increment()
        }
        XCTAssertFalse(counter.hasSwipesRemaining)
    }

    func testRemainingDecrementsOnIncrement() {
        let before = counter.remaining
        counter.increment()
        XCTAssertEqual(counter.remaining, before - 1)
    }

    func testRemainingNeverGoesBelowZero() {
        for _ in 0..<(SwipeCounter.freeLimit + 5) {
            counter.increment()
        }
        XCTAssertEqual(counter.remaining, 0)
    }

    func testCountResetsByInjectedDate() {
        // Simulate prior day by writing a past date directly
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.set("2000-01-01", forKey: "swipes_date")
        defaults.set(25,           forKey: "swipes_count")
        // todayCount should reset because date changed
        XCTAssertEqual(counter.todayCount, 0)
    }
}
