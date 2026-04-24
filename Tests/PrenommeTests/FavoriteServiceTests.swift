import XCTest
import SwiftData
@testable import Prenomme

final class FavoriteServiceTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!
    private var service: FavoriteService!

    override func setUp() {
        super.setUp()
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: Favorite.self, configurations: config)
        context   = ModelContext(container)
        service   = FavoriteService(context: context)
    }

    override func tearDown() {
        container = nil
        context   = nil
        service   = nil
        super.tearDown()
    }

    // MARK: — isFavorite

    func testIsFavoriteReturnsFalseInitially() {
        XCTAssertFalse(service.isFavorite(nameId: 1))
    }

    func testIsFavoriteReturnsTrueAfterAdd() {
        service.add(nameId: 1, isPro: true)
        XCTAssertTrue(service.isFavorite(nameId: 1))
    }

    // MARK: — add

    func testAddReturnAdded() {
        XCTAssertEqual(service.add(nameId: 1, isPro: true), .added)
    }

    func testAddReturnAlreadyAdded() {
        service.add(nameId: 1, isPro: true)
        XCTAssertEqual(service.add(nameId: 1, isPro: true), .alreadyAdded)
    }

    func testAddBlockedAtFreeLimit() {
        for id in 1...FavoriteService.freeLimit {
            service.add(nameId: id, isPro: false)
        }
        XCTAssertEqual(service.add(nameId: 999, isPro: false), .limitReached)
    }

    func testAddAllowedBeyondLimitForPro() {
        for id in 1...FavoriteService.freeLimit {
            service.add(nameId: id, isPro: true)
        }
        XCTAssertEqual(service.add(nameId: 999, isPro: true), .added)
    }

    // MARK: — remove

    func testRemoveDeletesFavorite() {
        service.add(nameId: 1, isPro: true)
        service.remove(nameId: 1)
        XCTAssertFalse(service.isFavorite(nameId: 1))
    }

    func testRemoveNonExistentIsNoOp() {
        service.remove(nameId: 999)  // should not crash
        XCTAssertEqual(service.favoriteCount(), 0)
    }

    // MARK: — toggle

    func testToggleAdds() {
        XCTAssertEqual(service.toggle(nameId: 1, isPro: true), .added)
        XCTAssertTrue(service.isFavorite(nameId: 1))
    }

    func testToggleRemoves() {
        service.add(nameId: 1, isPro: true)
        XCTAssertEqual(service.toggle(nameId: 1, isPro: true), .removed)
        XCTAssertFalse(service.isFavorite(nameId: 1))
    }

    // MARK: — favoriteCount

    func testFavoriteCountIncrements() {
        service.add(nameId: 1, isPro: true)
        service.add(nameId: 2, isPro: true)
        XCTAssertEqual(service.favoriteCount(), 2)
    }
}
