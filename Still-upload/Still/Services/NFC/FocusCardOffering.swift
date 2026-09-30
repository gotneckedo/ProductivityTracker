import Foundation

struct FocusCardOffer: Equatable {
    var setupURL: URL
    var isPreview: Bool
}

/// Content boundary for a future branded-card setup page. It deliberately has
/// no order, cart, price, payment, or fulfillment API.
protocol FocusCardOffering: AnyObject {
    var offer: FocusCardOffer? { get }
}

final class NoFocusCardOffering: FocusCardOffering {
    var offer: FocusCardOffer? { nil }
}

/// DEBUG/CI-demo-only placeholder. The reserved `.example` URL cannot be a
/// storefront and is replaced only after a real domain and setup page exist.
final class PlaceholderFocusCardOffering: FocusCardOffering {
    let offer: FocusCardOffer? = FocusCardOffer(setupURL: StillLinks.focusCardSetupURL, isPreview: true)
}
