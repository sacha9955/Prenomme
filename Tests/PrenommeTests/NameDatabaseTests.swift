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
}
