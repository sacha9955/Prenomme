import XCTest
@testable import Prenomme

final class NameDatabaseTests: XCTestCase {

    private func requirePopulatedDB() throws {
        let count = (try? NameDatabase.shared.all().count) ?? 0
        try XCTSkipIf(count == 0, "names.sqlite not bundled — run scripts/import_names.py first")
    }

    func testAllReturnsNames() throws {
        try requirePopulatedDB()
        let names = try NameDatabase.shared.all()
        XCTAssertFalse(names.isEmpty)
    }

    func testAllFilterByGender() throws {
        try requirePopulatedDB()
        let girls = try NameDatabase.shared.all(gender: .female)
        XCTAssertTrue(girls.allSatisfy { $0.gender == .female })
    }

    func testSearchReturnsMatchingNames() throws {
        try requirePopulatedDB()
        let results = try NameDatabase.shared.search("Emma")
        XCTAssertTrue(results.contains { $0.name == "Emma" })
    }

    func testByIdReturnsCorrectName() throws {
        try requirePopulatedDB()
        let name = try NameDatabase.shared.byId(1)
        XCTAssertEqual(name?.id, 1)
    }

    func testRandomReturnsName() throws {
        try requirePopulatedDB()
        let name = try NameDatabase.shared.random()
        XCTAssertNotNil(name)
    }

    func testNameForDateIsDeterministic() throws {
        try requirePopulatedDB()
        let date = Date(timeIntervalSinceReferenceDate: 0)
        let a = try NameDatabase.shared.nameForDate(date)
        let b = try NameDatabase.shared.nameForDate(date)
        XCTAssertEqual(a?.id, b?.id)
    }

    func testAllOriginsNotEmpty() throws {
        try requirePopulatedDB()
        XCTAssertFalse(NameDatabase.shared.allOrigins.isEmpty)
    }

    func testFilteredByGenderAndOrigin() throws {
        try requirePopulatedDB()
        var filter = NameFilter()
        filter.gender = .female
        filter.origins = ["Hébreu"]
        let results = try NameDatabase.shared.filtered(filter)
        XCTAssertTrue(results.allSatisfy { $0.gender == .female && $0.origin == "Hébreu" })
    }

    func testFilteredMultipleOrigins() throws {
        try requirePopulatedDB()
        var filter = NameFilter()
        filter.origins = ["Latin", "Grec"]
        let results = try NameDatabase.shared.filtered(filter)
        XCTAssertTrue(results.allSatisfy { $0.origin == "Latin" || $0.origin == "Grec" })
    }

    func testSearchEmptyStringReturnsNames() throws {
        try requirePopulatedDB()
        let results = try NameDatabase.shared.search("")
        XCTAssertFalse(results.isEmpty)
    }

    func testByIdNonexistentReturnsNil() throws {
        try requirePopulatedDB()
        let result = try NameDatabase.shared.byId(Int.max)
        XCTAssertNil(result)
    }
}
