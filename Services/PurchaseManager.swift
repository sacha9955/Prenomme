import StoreKit
import Foundation
import UIKit
import WidgetKit

@Observable
final class PurchaseManager: @unchecked Sendable {

    static let shared = PurchaseManager()

    // Product identifiers
    static let lifetimeID: String = "prenomme.pro.lifetime"
    static let monthlyID:  String = "prenomme.pro.monthly"
    static let yearlyID:   String = "prenomme.pro.yearly"

    private(set) var realIsPro: Bool = false
    private(set) var products: [Product] = []
    private(set) var isLoading: Bool = false
    private(set) var isLoadingProducts: Bool = true
    private(set) var purchaseError: String?
    private(set) var loadError: String?

    private let productIDs: Set<String> = [
        PurchaseManager.lifetimeID,
        PurchaseManager.monthlyID,
        PurchaseManager.yearlyID,
    ]
    private var updatesTask: Task<Void, Never>?
    private let sharedDefaults = UserDefaults(suiteName: "group.com.sacha9955.prenomme")

    #if DEBUG
    private(set) var debugForcePro: Bool = UserDefaults(suiteName: "group.com.sacha9955.prenomme")?.bool(forKey: "debug.forcePro") ?? false

    func setDebugForcePro(_ value: Bool) {
        debugForcePro = value
        sharedDefaults?.set(value, forKey: "debug.forcePro")
        WidgetCenter.shared.reloadAllTimelines()
    }
    #endif

    var isPro: Bool {
        #if DEBUG
        return realIsPro || debugForcePro
        #else
        return realIsPro
        #endif
    }

    // MARK: — Product accessors

    var lifetimeProduct: Product? { products.first { $0.id == Self.lifetimeID } }
    var monthlyProduct:  Product? { products.first { $0.id == Self.monthlyID } }
    var yearlyProduct:   Product? { products.first { $0.id == Self.yearlyID } }

    /// Backward-compat alias for the legacy lifetime product.
    var proProduct: Product? { lifetimeProduct }

    // Fallback prices when StoreKit fails to load (no network, no scheme config)
    static let fallbackLifetimePrice: String = "29,99 €"
    static let fallbackMonthlyPrice:  String = "2,99 €"
    static let fallbackYearlyPrice:   String = "19,99 €"
    static let fallbackPriceDisplay:  String = fallbackLifetimePrice

    init() {
        updatesTask = Task { [weak self] in
            await self?.listenForTransactionUpdates()
        }
        Task { [weak self] in
            await self?.loadProducts()
            await self?.refreshEntitlements()
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    // MARK: — Public API

    func purchase(_ product: Product, confirmIn scene: UIWindowScene? = nil) async {
        await MainActor.run { isLoading = true; purchaseError = nil }
        do {
            let result: Product.PurchaseResult
            if let scene {
                result = try await product.purchase(confirmIn: scene)
            } else {
                result = try await product.purchase()
            }
            switch result {
            case .success(let verification):
                guard case .verified(let tx) = verification else { break }
                await tx.finish()
                await refreshEntitlements()
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            await MainActor.run { purchaseError = error.localizedDescription }
        }
        await MainActor.run { isLoading = false }
    }

    func restore() async {
        await MainActor.run { isLoading = true }
        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            await MainActor.run { purchaseError = error.localizedDescription }
        }
        await MainActor.run { isLoading = false }
    }

    func retryLoadProducts() {
        Task { await loadProducts() }
    }

    // MARK: — Private

    private func loadProducts() async {
        await MainActor.run {
            isLoadingProducts = true
            loadError = nil
        }

        let retryDelays: [UInt64] = [2_000_000_000, 5_000_000_000]
        var loaded = false
        for (attempt, delay) in ([UInt64(0)] + retryDelays).enumerated() {
            if attempt > 0 {
                try? await Task.sleep(nanoseconds: delay)
            }
            do {
                let result = try await Product.products(for: productIDs)
                if !result.isEmpty {
                    await MainActor.run { products = result }
                    loaded = true
                    break
                }
            } catch {
                // retry on next iteration
            }
        }

        await MainActor.run {
            isLoadingProducts = false
            if !loaded {
                loadError = "Prix indisponible. Vérifiez votre connexion et réessayez."
            }
        }
    }

    private func refreshEntitlements() async {
        var entitled: Set<String> = []
        for await result in Transaction.currentEntitlements {
            if case .verified(let tx) = result {
                entitled.insert(tx.productID)
            }
        }
        // Pro is granted if user owns lifetime OR has an active subscription.
        let newIsPro = !entitled.isDisjoint(with: productIDs)
        await MainActor.run {
            let changed = newIsPro != realIsPro
            realIsPro = newIsPro
            sharedDefaults?.set(newIsPro, forKey: "isPro")
            if changed { WidgetCenter.shared.reloadAllTimelines() }
        }
    }

    private func listenForTransactionUpdates() async {
        for await result in Transaction.updates {
            if case .verified(let tx) = result {
                await tx.finish()
                await refreshEntitlements()
            }
        }
    }
}
