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
    /// The app contains no server paywall. Entitlement comes from StoreKit's
    /// current transaction state and is deliberately named for the actual plan.
    static let stillPlusMonthly = "com.cocomedia.still.plus.monthly"
    static let stillPlusYearly = "com.cocomedia.still.plus.yearly"
    static let productIDs: Set<String> = [stillPlusMonthly, stillPlusYearly]

    static let stillPlusPreview = SupporterProduct(
        id: stillPlusMonthly,
        displayName: "Still+ Monthly",
        description: "Physical Focus Card access, seasonal rooms, extra palettes, and future subscriber tools. Focus, tasks, and every session-earned room stay free.",
        displayPrice: "$4.99/month test price"
    )

    static let stillPlusYearlyPreview = SupporterProduct(
        id: stillPlusYearly,
        displayName: "Still+ Yearly",
        description: "The same Still+ benefits with a year of quiet focus tools.",
        displayPrice: "$39.99/year test price"
    )
}

/// StoreKit-facing boundary. Still+ is a renewable subscription; all entitlement
/// state remains on-device in StoreKit. There are no servers or ad trackers.
protocol PurchaseService: AnyObject {
    var isStandIn: Bool { get }
    var products: [SupporterProduct] { get }
    var purchasedProductIDs: Set<String> { get }
    func loadProducts() async
    func purchase(productID: String) async -> PurchaseOutcome
    func restorePurchases() async -> PurchaseOutcome
}

extension PurchaseService {
    /// The only entitlement predicate product UI should need. StoreKit keeps it
    /// current on-device for the real implementation; previews stay memory-only.
    var hasStillPlus: Bool {
        !purchasedProductIDs.isDisjoint(with: PurchaseProductCatalog.productIDs)
    }
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

    init(products: [SupporterProduct] = [PurchaseProductCatalog.stillPlusPreview, PurchaseProductCatalog.stillPlusYearlyPreview], purchased: Set<String> = []) {
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
