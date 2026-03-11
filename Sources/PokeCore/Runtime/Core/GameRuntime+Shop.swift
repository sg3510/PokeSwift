import Foundation
import PokeDataModel

extension GameRuntime {
    private static let shopMenuOptions: [RuntimeShopTransactionKind?] = [.buy, .sell, nil]

    func openMart(id martID: String) {
        guard content.mart(id: martID) != nil else { return }
        fieldPartyReorderState = nil
        shopState = RuntimeShopState(
            martID: martID,
            phase: .mainMenu,
            focusedMainMenuIndex: 0,
            focusedItemIndex: 0,
            focusedConfirmationIndex: 0,
            selectedQuantity: 1,
            transaction: nil,
            message: shopDialogueText(id: "pokemart_greeting", fallback: "Hi there! May I help you?"),
            nextPhaseAfterResult: nil
        )
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

        switch shopState.phase {
        case .mainMenu:
            handleShopMainMenu(button: button, state: &shopState)
        case .buyList:
            handleShopItemList(
                button: button,
                items: mart.stockItemIDs.compactMap { content.item(id: $0) },
                transactionKind: .buy,
                state: &shopState
            )
        case .sellList:
            handleShopItemList(
                button: button,
                items: sellInventoryItems(),
                transactionKind: .sell,
                state: &shopState
            )
        case .quantity:
            handleShopQuantitySelection(button: button, state: &shopState)
        case .confirmation:
            handleShopConfirmation(button: button, state: &shopState)
        case .result:
            handleShopResult(button: button, state: &shopState)
        }

        guard self.shopState != nil else {
            return
        }
        self.shopState = shopState
    }

    func handleShopMainMenu(button: RuntimeButton, state: inout RuntimeShopState) {
        switch button {
        case .up, .left:
            state.focusedMainMenuIndex = (state.focusedMainMenuIndex - 1 + Self.shopMenuOptions.count) % Self.shopMenuOptions.count
        case .down, .right:
            state.focusedMainMenuIndex = (state.focusedMainMenuIndex + 1) % Self.shopMenuOptions.count
        case .confirm, .start:
            playUIConfirmSound()
            switch Self.shopMenuOptions[state.focusedMainMenuIndex] {
            case .buy:
                state.phase = .buyList
                state.transaction = nil
                state.focusedItemIndex = 0
                state.message = shopDialogueText(id: "pokemart_buying_greeting", fallback: "Take your time.")
            case .sell:
                let sellItems = sellInventoryItems()
                if sellItems.isEmpty {
                    showShopResult(
                        message: shopDialogueText(id: "pokemart_item_bag_empty", fallback: "You don't have anything to sell."),
                        nextPhase: .mainMenu,
                        state: &state
                    )
                } else {
                    state.phase = .sellList
                    state.transaction = nil
                    state.focusedItemIndex = min(state.focusedItemIndex, max(0, sellItems.count - 1))
                    state.message = shopDialogueText(id: "pokemart_selling_greeting", fallback: "What would you like to sell?")
                }
            case nil:
                closeMart()
                return
            }
        case .cancel:
            playUIConfirmSound()
            closeMart()
            return
        }
    }

    func handleShopItemList(
        button: RuntimeButton,
        items: [ItemManifest],
        transactionKind: RuntimeShopTransactionKind,
        state: inout RuntimeShopState
    ) {
        guard items.isEmpty == false else {
            showShopResult(
                message: shopDialogueText(id: "pokemart_item_bag_empty", fallback: "You don't have anything to sell."),
                nextPhase: .mainMenu,
                state: &state
            )
            return
        }

        let clampedIndex = max(0, min(items.count - 1, state.focusedItemIndex))
        state.focusedItemIndex = clampedIndex
        let selectedItem = items[clampedIndex]

        switch button {
        case .up:
            state.focusedItemIndex = (clampedIndex - 1 + items.count) % items.count
        case .down:
            state.focusedItemIndex = (clampedIndex + 1) % items.count
        case .confirm, .start:
            playUIConfirmSound()
            if transactionKind == .sell, canSell(item: selectedItem) == false {
                showShopResult(
                    message: shopDialogueText(id: "pokemart_unsellable_item", fallback: "I can't put a price on that."),
                    nextPhase: .mainMenu,
                    state: &state
                )
                return
            }

            state.phase = .quantity
            state.transaction = RuntimeShopTransactionState(kind: transactionKind, itemID: selectedItem.id)
            state.selectedQuantity = 1
            state.focusedConfirmationIndex = 0
            state.message = transactionKind == .buy
                ? "How many would you like?"
                : "How many will you sell?"
        case .cancel:
            playUIConfirmSound()
            returnToShopMainMenu(state: &state)
        case .left, .right:
            break
        }
    }

    func handleShopQuantitySelection(button: RuntimeButton, state: inout RuntimeShopState) {
        guard let transaction = state.transaction,
              let item = content.item(id: transaction.itemID) else {
            returnToShopMainMenu(state: &state)
            return
        }

        let maximumQuantity = maxShopQuantity(for: transaction, item: item)
        guard maximumQuantity > 0 else {
            showShopResult(
                message: transaction.kind == .buy
                    ? shopDialogueText(id: "pokemart_not_enough_money", fallback: "You don't have enough money.")
                    : shopDialogueText(id: "pokemart_item_bag_empty", fallback: "You don't have anything to sell."),
                nextPhase: .mainMenu,
                state: &state
            )
            return
        }

        switch button {
        case .up, .right:
            state.selectedQuantity = min(maximumQuantity, state.selectedQuantity + 1)
        case .down, .left:
            state.selectedQuantity = max(1, state.selectedQuantity - 1)
        case .confirm, .start:
            playUIConfirmSound()
            state.selectedQuantity = min(maximumQuantity, max(1, state.selectedQuantity))
            state.focusedConfirmationIndex = 0
            state.phase = .confirmation
            state.message = confirmationPrompt(for: item, quantity: state.selectedQuantity, kind: transaction.kind)
        case .cancel:
            playUIConfirmSound()
            state.phase = transaction.kind == .buy ? .buyList : .sellList
            state.message = transaction.kind == .buy
                ? shopDialogueText(id: "pokemart_buying_greeting", fallback: "Take your time.")
                : shopDialogueText(id: "pokemart_selling_greeting", fallback: "What would you like to sell?")
        }
    }

    func handleShopConfirmation(button: RuntimeButton, state: inout RuntimeShopState) {
        guard let transaction = state.transaction,
              let item = content.item(id: transaction.itemID) else {
            returnToShopMainMenu(state: &state)
            return
        }

        switch button {
        case .up, .down, .left, .right:
            state.focusedConfirmationIndex = state.focusedConfirmationIndex == 0 ? 1 : 0
        case .confirm, .start:
            playUIConfirmSound()
            if state.focusedConfirmationIndex == 1 {
                state.phase = transaction.kind == .buy ? .buyList : .sellList
                state.message = transaction.kind == .buy
                    ? shopDialogueText(id: "pokemart_buying_greeting", fallback: "Take your time.")
                    : shopDialogueText(id: "pokemart_selling_greeting", fallback: "What would you like to sell?")
                return
            }

            switch transaction.kind {
            case .buy:
                confirmShopPurchase(item: item, state: &state)
            case .sell:
                confirmShopSale(item: item, state: &state)
            }
        case .cancel:
            playUIConfirmSound()
            state.phase = .quantity
            state.message = transaction.kind == .buy ? "How many would you like?" : "How many will you sell?"
        }
    }

    func handleShopResult(button: RuntimeButton, state: inout RuntimeShopState) {
        switch button {
        case .confirm, .start, .cancel:
            playUIConfirmSound()
            let nextPhase = state.nextPhaseAfterResult ?? .mainMenu
            state.nextPhaseAfterResult = nil

            switch nextPhase {
            case .mainMenu:
                returnToShopMainMenu(state: &state)
            case .buyList:
                state.phase = .buyList
                state.transaction = nil
                state.selectedQuantity = 1
                state.focusedConfirmationIndex = 0
                state.message = shopDialogueText(id: "pokemart_buying_greeting", fallback: "Take your time.")
            case .sellList:
                state.phase = .sellList
                state.transaction = nil
                state.selectedQuantity = 1
                state.focusedConfirmationIndex = 0
                state.message = shopDialogueText(id: "pokemart_selling_greeting", fallback: "What would you like to sell?")
            case .quantity, .confirmation, .result:
                returnToShopMainMenu(state: &state)
            }
        case .up, .down, .left, .right:
            break
        }
    }

    func confirmShopPurchase(item: ItemManifest, state: inout RuntimeShopState) {
        let quantity = min(state.selectedQuantity, maxPurchasableQuantity(for: item))
        guard quantity > 0 else {
            let hasMoney = gameplayState.map { canAfford(item.price, gameplayState: $0) } ?? false
            let message = hasMoney
                ? shopDialogueText(id: "pokemart_item_bag_full", fallback: "You can't carry any more items.")
                : shopDialogueText(id: "pokemart_not_enough_money", fallback: "You don't have enough money.")
            showShopResult(message: message, nextPhase: .mainMenu, state: &state)
            return
        }

        if purchaseItem(item.id, quantity: quantity) {
            traceEvent(
                .shopPurchase,
                "Purchased \(quantity)x \(item.id).",
                mapID: gameplayState?.mapID,
                details: [
                    "martID": state.martID,
                    "itemID": item.id,
                    "quantity": String(quantity),
                    "operation": "buy",
                ]
            )
            showShopResult(
                message: shopDialogueText(id: "pokemart_bought_item", fallback: "Here you are! Thank you!"),
                nextPhase: .buyList,
                state: &state
            )
            return
        }

        let failureMessage = (gameplayState.map { canAfford(item.price * quantity, gameplayState: $0) } ?? false)
            ? shopDialogueText(id: "pokemart_item_bag_full", fallback: "You can't carry any more items.")
            : shopDialogueText(id: "pokemart_not_enough_money", fallback: "You don't have enough money.")
        showShopResult(message: failureMessage, nextPhase: .mainMenu, state: &state)
    }

    func confirmShopSale(item: ItemManifest, state: inout RuntimeShopState) {
        guard var gameplayState else {
            showShopResult(
                message: shopDialogueText(id: "pokemart_item_bag_empty", fallback: "You don't have anything to sell."),
                nextPhase: .mainMenu,
                state: &state
            )
            return
        }

        let quantity = min(state.selectedQuantity, itemQuantity(item.id))
        guard quantity > 0 else {
            showShopResult(
                message: shopDialogueText(id: "pokemart_item_bag_empty", fallback: "You don't have anything to sell."),
                nextPhase: .mainMenu,
                state: &state
            )
            return
        }
        guard canSell(item: item) else {
            showShopResult(
                message: shopDialogueText(id: "pokemart_unsellable_item", fallback: "I can't put a price on that."),
                nextPhase: .mainMenu,
                state: &state
            )
            return
        }
        guard removeItem(item.id, quantity: quantity, from: &gameplayState) else {
            showShopResult(
                message: shopDialogueText(id: "pokemart_item_bag_empty", fallback: "You don't have anything to sell."),
                nextPhase: .mainMenu,
                state: &state
            )
            return
        }

        gameplayState.money += sellPrice(for: item) * quantity
        self.gameplayState = gameplayState
        traceEvent(
            .inventoryChanged,
            "Sold \(quantity)x \(item.id).",
            mapID: gameplayState.mapID,
            details: [
                "itemID": item.id,
                "quantity": String(quantity),
                "operation": "sell",
                "remainingMoney": String(gameplayState.money),
            ]
        )
        traceEvent(
            .shopPurchase,
            "Sold \(quantity)x \(item.id).",
            mapID: gameplayState.mapID,
            details: [
                "martID": state.martID,
                "itemID": item.id,
                "quantity": String(quantity),
                "operation": "sell",
            ]
        )
        showShopResult(
            message: shopDialogueText(id: "pokemart_anything_else", fallback: "Is there anything else I can do?"),
            nextPhase: .sellList,
            state: &state
        )
    }

    func showShopResult(
        message: String,
        nextPhase: RuntimeShopPhase,
        state: inout RuntimeShopState
    ) {
        state.phase = .result
        state.message = message
        state.nextPhaseAfterResult = nextPhase
        state.focusedConfirmationIndex = 0
        state.selectedQuantity = 1
        state.transaction = nil
    }

    func returnToShopMainMenu(state: inout RuntimeShopState) {
        state.phase = .mainMenu
        state.transaction = nil
        state.selectedQuantity = 1
        state.focusedConfirmationIndex = 0
        state.message = shopDialogueText(id: "pokemart_anything_else", fallback: "Is there anything else I can do?")
    }

    func sellInventoryItems() -> [ItemManifest] {
        currentInventoryItems.compactMap { itemState in
            content.item(id: itemState.itemID)
        }
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

    func maxShopQuantity(for transaction: RuntimeShopTransactionState, item: ItemManifest) -> Int {
        switch transaction.kind {
        case .buy:
            return maxPurchasableQuantity(for: item)
        case .sell:
            return itemQuantity(item.id)
        }
    }

    func canSell(item: ItemManifest) -> Bool {
        item.isKeyItem == false && item.id.hasPrefix("HM_") == false && item.price > 0
    }

    func sellPrice(for item: ItemManifest) -> Int {
        max(0, item.price / 2)
    }

    func confirmationPrompt(for item: ItemManifest, quantity: Int, kind: RuntimeShopTransactionKind) -> String {
        let totalPrice = (kind == .buy ? item.price : sellPrice(for: item)) * quantity
        switch kind {
        case .buy:
            return "\(item.displayName)? That will be ¥\(totalPrice). OK?"
        case .sell:
            return "I can pay you ¥\(totalPrice) for that."
        }
    }

    func shopDialogueText(id: String, fallback: String) -> String {
        guard let dialogue = content.dialogue(id: id) else {
            return fallback
        }

        let lines = dialogue.pages.flatMap(\.lines)
        guard lines.isEmpty == false else {
            return fallback
        }
        return lines.joined(separator: " ")
    }
}
