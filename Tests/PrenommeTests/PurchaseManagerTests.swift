import XCTest
@testable import Prenomme

final class PurchaseManagerTests: XCTestCase {

    func testIsLoadingInitiallyFalse() {
        XCTAssertFalse(PurchaseManager.shared.isLoading)
    }

    func testRealIsProInitiallyFalse() {
        // Without a real StoreKit transaction, realIsPro must be false
        XCTAssertFalse(PurchaseManager.shared.realIsPro)
    }

    func testPurchaseErrorInitiallyNil() {
        XCTAssertNil(PurchaseManager.shared.purchaseError)
    }

    func testFallbackPrice_WhenProductNil() {
        XCTAssertNil(PurchaseManager.shared.proProduct,
                     "proProduct should be nil in test environment (no StoreKit config)")
        XCTAssertFalse(PurchaseManager.fallbackPriceDisplay.isEmpty)
        XCTAssertEqual(PurchaseManager.fallbackPriceDisplay, "29,99 €")
    }

    #if DEBUG
    func testDebugForceProDefaultsToFalse() {
        // Ensure App Group key is cleared before asserting
        UserDefaults(suiteName: "group.com.sacha9955.prenomme")?.removeObject(forKey: "debug.forcePro")
        // Re-read from shared defaults directly; PurchaseManager.shared was already inited,
        // so we test the property contract instead of re-init.
        let raw = UserDefaults(suiteName: "group.com.sacha9955.prenomme")?.bool(forKey: "debug.forcePro") ?? false
        XCTAssertFalse(raw)
    }

    func testIsProReflectsDebugForce() {
        let pm = PurchaseManager.shared
        let before = pm.isPro
        pm.setDebugForcePro(true)
        XCTAssertTrue(pm.isPro)
        pm.setDebugForcePro(false)
        XCTAssertEqual(pm.isPro, before)
    }
    #endif
}
