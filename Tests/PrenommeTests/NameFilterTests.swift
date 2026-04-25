import XCTest
@testable import Prenomme

final class NameFilterTests: XCTestCase {

    func testDefaultFilterIsInactive() {
        let filter = NameFilter()
        XCTAssertFalse(filter.isActive)
    }

    func testDefaultValues() {
        let filter = NameFilter()
        XCTAssertNil(filter.gender)
        XCTAssertTrue(filter.origins.isEmpty)
        XCTAssertNil(filter.syllables)
        XCTAssertNil(filter.initialLetter)
        XCTAssertEqual(filter.searchQuery, "")
        XCTAssertTrue(filter.sortByPopularity)
    }

    func testIsActiveWithGender() {
        var filter = NameFilter()
        filter.gender = .female
        XCTAssertTrue(filter.isActive)
    }

    func testIsActiveWithOrigins() {
        var filter = NameFilter()
        filter.origins = ["Hébreu"]
        XCTAssertTrue(filter.isActive)
    }

    func testIsActiveWithInitialLetter() {
        var filter = NameFilter()
        filter.initialLetter = "A"
        XCTAssertTrue(filter.isActive)
    }

    func testIsActiveWithSyllables() {
        var filter = NameFilter()
        filter.syllables = 2
        XCTAssertTrue(filter.isActive)
    }

    func testSearchQueryAloneDoesNotActivate() {
        // searchQuery is not part of isActive — it's a separate search path
        var filter = NameFilter()
        filter.searchQuery = "Emma"
        XCTAssertFalse(filter.isActive)
    }

    func testEquality() {
        var a = NameFilter()
        var b = NameFilter()
        XCTAssertEqual(a, b)
        a.gender = .male
        XCTAssertNotEqual(a, b)
        b.gender = .male
        XCTAssertEqual(a, b)
    }
}
