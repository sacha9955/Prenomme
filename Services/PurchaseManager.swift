import StoreKit
import Foundation
import WidgetKit

@Observable
final class PurchaseManager: @unchecked Sendable {

    static let shared = PurchaseManager()

    private(set) var realIsPro: Bool = false
    private(set) var products: [Product] = []
    private(set) var isLoading: Bool = false
    private(set) var isLoadingProducts: Bool = true
    private(set) var purchaseError: String?
    private(set) var loadError: String?

    private let productIDs: Set<String> = ["prenomme.pro.lifetime"]
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

    var proProduct: Product? {
        products.first(where: { $0.id == "prenomme.pro.lifetime" })
    }

    // Shown when StoreKit fails to return the product (no network, no scheme config, etc.)
    static let fallbackPriceDisplay: String = "8,99 €"

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

    func purchase(_ product: Product) async {
        isLoading = true
        purchaseError = nil
        defer { isLoading = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard case .verified(let tx) = verification else { return }
                await tx.finish()
                await refreshEntitlements()
            case .userCancelled:
                break
            case .pending:
                break
            @unknown default:
                break
            }
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    func restore() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    func retryLoadProducts() {
        Task { await loadProducts() }
    }

    // MARK: — Private

    private func loadProducts() async {
        isLoadingProducts = true
        loadError = nil
        defer { isLoadingProducts = false }

        let retryDelays: [UInt64] = [2_000_000_000, 5_000_000_000]
        for (attempt, delay) in ([UInt64(0)] + retryDelays).enumerated() {
            if attempt > 0 {
                try? await Task.sleep(nanoseconds: delay)
            }
            do {
                let result = try await Product.products(for: productIDs)
                if !result.isEmpty {
                    products = result
                    return
                }
            } catch {
                // retry on next iteration
            }
        }
        loadError = "Prix indisponible. Vérifiez votre connexion et réessayez."
    }

    private func refreshEntitlements() async {
        var entitled: Set<String> = []
        for await result in Transaction.currentEntitlements {
            if case .verified(let tx) = result {
                entitled.insert(tx.productID)
            }
        }
        let newIsPro = entitled.contains("prenomme.pro.lifetime")
        let changed = newIsPro != realIsPro
        realIsPro = newIsPro
        sharedDefaults?.set(newIsPro, forKey: "isPro")
        if changed { WidgetCenter.shared.reloadAllTimelines() }
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
