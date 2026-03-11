import Foundation
import PokeDataModel

extension GameRuntime {
    func openMart(id martID: String) {
        guard content.mart(id: martID) != nil else { return }
        shopState = RuntimeShopState(martID: martID, selectedItemIndex: 0, selectedQuantity: 1)
        substate = "shop_\(martID)"
        traceEvent(.shopOpened, "Opened mart \(martID).", mapID: gameplayState?.mapID, details: ["martID": martID])
    }

    func closeMart(traceCancellation: Bool = true) {
        guard let shopState else { return }
        if traceCancellation {
            traceEvent(.shopClosed, "Closed mart \(shopState.martID).", mapID: gameplayState?.mapID, details: ["martID": shopState.martID])
        }
        self.shopState = nil
        substate = "field"
    }

    func handleShop(button: RuntimeButton) {
        guard var shopState, let mart = content.mart(id: shopState.martID) else {
            closeMart(traceCancellation: false)
            return
        }

        let stock = mart.stockItemIDs.compactMap { content.item(id: $0) }
        guard stock.isEmpty == false else {
            closeMart(traceCancellation: false)
            return
        }

        let selectedIndex = max(0, min(stock.count - 1, shopState.selectedItemIndex))
        let selectedItem = stock[selectedIndex]

        switch button {
        case .up:
            shopState.selectedItemIndex = (selectedIndex - 1 + stock.count) % stock.count
            shopState.selectedQuantity = 1
        case .down:
            shopState.selectedItemIndex = (selectedIndex + 1) % stock.count
            shopState.selectedQuantity = 1
        case .left:
            let nextQuantity = max(1, shopState.selectedQuantity - 1)
            shopState.selectedQuantity = nextQuantity
        case .right:
            shopState.selectedQuantity = min(maxPurchasableQuantity(for: selectedItem), shopState.selectedQuantity + 1)
        case .confirm, .start:
            let quantity = min(shopState.selectedQuantity, maxPurchasableQuantity(for: selectedItem))
            guard quantity > 0 else {
                playCollisionSoundIfNeeded()
                return
            }
            playUIConfirmSound()
            if purchaseItem(selectedItem.id, quantity: quantity) {
                traceEvent(
                    .shopPurchase,
                    "Purchased \(quantity)x \(selectedItem.id).",
                    mapID: gameplayState?.mapID,
                    details: [
                        "martID": mart.id,
                        "itemID": selectedItem.id,
                        "quantity": String(quantity),
                    ]
                )
            }
            shopState.selectedQuantity = min(maxPurchasableQuantity(for: selectedItem), max(1, shopState.selectedQuantity))
        case .cancel:
            playUIConfirmSound()
            closeMart()
            return
        }

        self.shopState = shopState
    }

    func maxPurchasableQuantity(for item: ItemManifest) -> Int {
        guard let gameplayState else { return 0 }
        guard item.price > 0 else { return 0 }

        let affordable = max(0, gameplayState.money / item.price)
        let existingQuantity = gameplayState.inventory.first(where: { $0.itemID == item.id })?.quantity ?? 0
        let stackHeadroom = max(0, Self.maxItemStackQuantity - existingQuantity)
        let hasStack = existingQuantity > 0
        let canOpenNewSlot = hasStack || gameplayState.inventory.count < Self.bagItemCapacity
        guard canOpenNewSlot else { return 0 }
        return min(Self.maxItemStackQuantity, affordable, stackHeadroom)
    }
}
