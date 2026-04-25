import StoreKit
import Foundation
import WidgetKit

@Observable
final class PurchaseManager: @unchecked Sendable {

    static let shared = PurchaseManager()

    private(set) var isPro: Bool = false
    private(set) var products: [Product] = []
    private(set) var isLoading: Bool = false
    private(set) var purchaseError: String?

    private let productIDs: Set<String> = ["prenomme.pro.lifetime"]
    private var updatesTask: Task<Void, Never>?
    private let sharedDefaults = UserDefaults(suiteName: "group.com.sacha9955.prenomme")

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

    var proProduct: Product? {
        products.first(where: { $0.id == "prenomme.pro.lifetime" })
    }

    // MARK: — Private

    private func loadProducts() async {
        do {
            products = try await Product.products(for: productIDs)
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    private func refreshEntitlements() async {
        var entitled: Set<String> = []
        for await result in Transaction.currentEntitlements {
            if case .verified(let tx) = result {
                entitled.insert(tx.productID)
            }
        }
        let newIsPro = entitled.contains("prenomme.pro.lifetime")
        let changed = newIsPro != isPro
        isPro = newIsPro
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
