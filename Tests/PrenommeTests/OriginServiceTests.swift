import XCTest
@testable import Prenomme

final class OriginServiceTests: XCTestCase {

    func testOriginsNotEmpty() {
        XCTAssertFalse(OriginService.shared.origins.isEmpty, "OriginService should expose at least one origin")
    }

    func testAllOriginsHaveCount() {
        for origin in OriginService.shared.origins {
            XCTAssertGreaterThan(origin.count, 0, "\(origin.name) should have count > 0")
        }
    }

    func testAllOriginsHaveColors() {
        for origin in OriginService.shared.origins {
            XCTAssertEqual(origin.colors.count, 2, "\(origin.name) should have exactly 2 colors")
        }
    }

    func testAllOriginsHaveDescription() {
        for origin in OriginService.shared.origins {
            XCTAssertFalse(origin.description.isEmpty, "\(origin.name) should have a description")
        }
    }

    func testOriginNamesAreUnique() {
        let names = OriginService.shared.origins.map(\.name)
        let uniqueNames = Set(names)
        XCTAssertEqual(names.count, uniqueNames.count, "Origin names should be unique")
    }

    func testOriginCountMatchesDatabase() {
        let dbCounts = NameDatabase.shared.countByOrigin()
        for origin in OriginService.shared.origins {
            let expected = dbCounts[origin.name] ?? 0
            XCTAssertEqual(origin.count, expected, "\(origin.name) count should match database")
        }
    }

    func testPublicOriginsExcludesAutre() {
        let publicNames = OriginService.shared.publicOrigins.map(\.name)
        XCTAssertFalse(publicNames.contains("Autre"), "publicOrigins should not expose 'Autre'")
    }

    func testAllOriginsIncludesAutre() {
        let allNames = OriginService.shared.origins.map(\.name)
        XCTAssertTrue(allNames.contains("Autre"), "origins (full list) should include 'Autre'")
    }
}
