import XCTest
@testable import Prenomme

final class NameDatabaseTests: XCTestCase {

    func testAllReturnsNames() throws {
        let names = try NameDatabase.shared.all()
        XCTAssertFalse(names.isEmpty, "La base doit contenir des prénoms")
    }

    func testAllFilterByGender() throws {
        let girls = try NameDatabase.shared.all(gender: .female)
        XCTAssertTrue(girls.allSatisfy { $0.gender == .female })
    }

    func testSearchReturnsMatchingNames() throws {
        let results = try NameDatabase.shared.search("Emma")
        XCTAssertTrue(results.contains { $0.name == "Emma" })
    }

    func testByIdReturnsCorrectName() throws {
        let name = try NameDatabase.shared.byId(1)
        XCTAssertEqual(name?.id, 1)
    }

    func testRandomReturnsName() throws {
        let name = try NameDatabase.shared.random()
        XCTAssertNotNil(name)
    }

    func testNameForDateIsDeterministic() throws {
        let date = Date(timeIntervalSinceReferenceDate: 0)
        let a = try NameDatabase.shared.nameForDate(date)
        let b = try NameDatabase.shared.nameForDate(date)
        XCTAssertEqual(a?.id, b?.id)
    }

    func testAllOriginsNotEmpty() {
        XCTAssertFalse(NameDatabase.shared.allOrigins.isEmpty)
    }
}
