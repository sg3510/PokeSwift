import Foundation

extension GameRuntime {
    func clearFieldPartyReorderState() {
        guard fieldPartyReorderState != nil else { return }
        fieldPartyReorderState = nil
    }

    public func handlePartySidebarSelection(_ index: Int) {
        switch scene {
        case .field:
            handleFieldPartySidebarSelection(index)
        case .battle:
            handleBattlePartySidebarSelection(index)
        default:
            break
        }
    }

    func handleFieldPartySidebarSelection(_ index: Int) {
        guard dialogueState == nil,
              shopState == nil,
              fieldTransitionState == nil,
              scriptedMovementTask == nil,
              var gameplayState,
              gameplayState.playerParty.indices.contains(index),
              gameplayState.playerParty.count > 1 else {
            return
        }

        playUIConfirmSound()

        if let reorderState = fieldPartyReorderState {
            if reorderState.selectedIndex == index {
                fieldPartyReorderState = nil
                publishSnapshot()
                return
            }

            gameplayState.playerParty.swapAt(reorderState.selectedIndex, index)
            self.gameplayState = gameplayState
            fieldPartyReorderState = nil
            publishSnapshot()
            return
        }

        fieldPartyReorderState = RuntimeFieldPartyReorderState(selectedIndex: index)
        publishSnapshot()
    }

    func handleBattlePartySidebarSelection(_ index: Int) {
        guard var gameplayState,
              var battle = gameplayState.battle,
              battle.phase == .partySelection,
              gameplayState.playerParty.indices.contains(index) else {
            return
        }

        battle.focusedPartyIndex = index
        resolveBattlePartySelection(battle: &battle, gameplayState: &gameplayState)

        guard scene == .battle else {
            return
        }

        gameplayState.playerParty = syncedPlayerParty(from: battle, gameplayState: gameplayState)
        gameplayState.battle = battle
        self.gameplayState = gameplayState
        substate = "battle"
        publishSnapshot()
    }
}
