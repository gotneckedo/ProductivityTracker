#if canImport(StoreKit) && os(iOS)
import Foundation
import StoreKit

/// Real StoreKit 2 boundary. In DEBUG it reads the checked-in local StoreKit
/// configuration; App Store products with the same IDs can replace it later.
final class StoreKitPurchaseService: PurchaseService {
    var isStandIn: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }
    private(set) var products: [SupporterProduct] = []
    private(set) var purchasedProductIDs: Set<String> = []
    private var storeProducts: [String: Product] = [:]

    func loadProducts() async {
        do {
            let loaded = try await Product.products(for: PurchaseProductCatalog.productIDs)
            storeProducts = Dictionary(uniqueKeysWithValues: loaded.map { ($0.id, $0) })
            products = loaded.map {
                SupporterProduct(id: $0.id, displayName: $0.displayName,
                                 description: $0.description, displayPrice: $0.displayPrice)
            }
            await refreshEntitlements()
        } catch {
            products = []
        }
    }

    func purchase(productID: String) async -> PurchaseOutcome {
        guard let product = storeProducts[productID] else {
            return .unavailable("The local StoreKit product is not loaded.")
        }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    purchasedProductIDs.insert(transaction.productID)
                    await transaction.finish()
                    return .purchased
                case .unverified:
                    return .failed("StoreKit could not verify this transaction.")
                }
            case .pending:
                return .pending
            case .userCancelled:
                return .cancelled
            @unknown default:
                return .failed("StoreKit returned an unknown result.")
            }
        } catch {
            return .failed("The StoreKit test purchase did not finish.")
        }
    }

    func restorePurchases() async -> PurchaseOutcome {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            return purchasedProductIDs.isEmpty
                ? .unavailable("No StoreKit test purchase was found.")
                : .purchased
        } catch {
            return .failed("StoreKit could not restore purchases.")
        }
    }

    private func refreshEntitlements() async {
        var entitlements: Set<String> = []
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               PurchaseProductCatalog.productIDs.contains(transaction.productID),
               transaction.revocationDate == nil {
                entitlements.insert(transaction.productID)
            }
        }
        purchasedProductIDs = entitlements
    }
}
#endif
