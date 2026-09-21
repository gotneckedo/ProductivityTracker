import Foundation

struct SupporterProduct: Identifiable, Hashable {
    var id: String
    var displayName: String
    var description: String
    var displayPrice: String
}

enum PurchaseOutcome: Equatable {
    case purchased
    case pending
    case cancelled
    case unavailable(String)
    case failed(String)
}

enum PurchaseProductCatalog {
    static let supporter = "com.cocomedia.still.supporter"
    static let productIDs: Set<String> = [supporter]

    static let supporterPreview = SupporterProduct(
        id: supporter,
        displayName: "Still Supporter",
        description: "Seasonal rooms, extra palettes, and future alternate app icons. Focus tools and everything earned by using Still stay free.",
        displayPrice: "$4.99 test price"
    )
}

/// StoreKit-facing boundary. Purchases are non-consumable cosmetics only; there
/// are no subscriptions, timers, or server checks.
protocol PurchaseService: AnyObject {
    var isStandIn: Bool { get }
    var products: [SupporterProduct] { get }
    var purchasedProductIDs: Set<String> { get }
    func loadProducts() async
    func purchase(productID: String) async -> PurchaseOutcome
    func restorePurchases() async -> PurchaseOutcome
}

final class NoPurchaseService: PurchaseService {
    var isStandIn: Bool { false }
    var products: [SupporterProduct] { [] }
    var purchasedProductIDs: Set<String> { [] }

    func loadProducts() async {}
    func purchase(productID: String) async -> PurchaseOutcome { .unavailable("Purchases are not available in this build.") }
    func restorePurchases() async -> PurchaseOutcome { .unavailable("Purchases are not available in this build.") }
}

/// Linux, SwiftUI preview, and unit-test stand-in. It records an entitlement in
/// memory only and never claims money changed hands.
final class LocalPurchaseService: PurchaseService {
    var isStandIn: Bool { true }
    private(set) var products: [SupporterProduct]
    private(set) var purchasedProductIDs: Set<String>

    init(products: [SupporterProduct] = [PurchaseProductCatalog.supporterPreview], purchased: Set<String> = []) {
        self.products = products
        self.purchasedProductIDs = purchased
    }

    func loadProducts() async {}

    func purchase(productID: String) async -> PurchaseOutcome {
        guard products.contains(where: { $0.id == productID }) else {
            return .unavailable("That test product is not in the local catalog.")
        }
        purchasedProductIDs.insert(productID)
        return .purchased
    }

    func restorePurchases() async -> PurchaseOutcome {
        purchasedProductIDs.isEmpty ? .unavailable("No local test purchase is recorded in this preview.") : .purchased
    }
}
