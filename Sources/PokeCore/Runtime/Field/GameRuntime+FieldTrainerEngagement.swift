import Foundation
import PokeDataModel

extension GameRuntime {
    func evaluateTrainerSightIfNeeded() -> Bool {
        guard
            trainerEngagementTask == nil,
            scene == .field,
            dialogueState == nil,
            gameplayState?.activeScriptID == nil,
            let gameplayState,
            let map = currentMapManifest
        else {
            return false
        }

        for objectManifest in map.objects {
            guard
                objectManifest.trainerBattleID != nil,
                objectManifest.trainerEngageDistance != nil,
                isTrainerDefeated(objectManifest) == false,
                let objectState = gameplayState.objectStates[objectManifest.id],
                objectState.visible,
                let engagementPath = trainerEngagementPath(for: objectManifest, objectState: objectState, map: map)
            else {
                continue
            }

            startTrainerEngagement(
                objectID: objectManifest.id,
                battleID: objectManifest.trainerBattleID,
                introDialogueID: objectManifest.trainerIntroDialogueID,
                path: engagementPath
            )
            return true
        }

        return false
    }

    func startTrainerEngagement(
        objectID: String,
        battleID: String?,
        introDialogueID: String?,
        path: [FacingDirection]
    ) {
        guard let battleID else { return }
        clearHeldFieldDirections()
        trainerEngagementTask?.cancel()
        trainerEngagementTask = Task { [weak self] in
            await self?.runTrainerEngagement(
                objectID: objectID,
                battleID: battleID,
                introDialogueID: introDialogueID,
                path: path
            )
        }
    }

    func runTrainerEngagement(
        objectID: String,
        battleID: String,
        introDialogueID: String?,
        path: [FacingDirection]
    ) async {
        defer {
            clearFieldAlert()
            trainerEngagementTask = nil
        }

        requestTrainerEncounterMusic(for: battleID)
        await showTrainerSightAlert(objectID: objectID)
        guard Task.isCancelled == false else { return }

        await animateObjectMovement(actorID: objectID, path: path)
        guard Task.isCancelled == false, var gameplayState else { return }
        let trainerFacing = gameplayState.objectStates[objectID]?.facing ?? .down
        gameplayState.facing = oppositeFacingDirection(of: trainerFacing)
        self.gameplayState = gameplayState
        beginTrainerEncounter(
            battleID: battleID,
            sourceTrainerObjectID: objectID,
            introDialogueID: introDialogueID
        )
    }

    func beginTrainerEncounter(
        battleID: String,
        sourceTrainerObjectID: String?,
        introDialogueID: String?
    ) {
        requestTrainerEncounterMusic(for: battleID)
        if let introDialogueID {
            showDialogue(
                id: introDialogueID,
                completion: .startBattle(
                    battleID: battleID,
                    sourceTrainerObjectID: sourceTrainerObjectID
                )
            )
            return
        }

        startBattle(
            id: battleID,
            sourceTrainerObjectID: sourceTrainerObjectID
        )
    }

    func showTrainerSightAlert(objectID: String) async {
        fieldAlertState = .init(objectID: objectID, kind: .exclamation)
        publishSnapshot()
        try? await Task.sleep(for: .seconds(1))
        guard Task.isCancelled == false else { return }
        clearFieldAlert()
    }

    func clearFieldAlert() {
        guard fieldAlertState != nil else { return }
        fieldAlertState = nil
        publishSnapshot()
    }

    func trainerEngagementPath(
        for objectManifest: MapObjectManifest,
        objectState: RuntimeObjectState,
        map: MapManifest
    ) -> [FacingDirection]? {
        guard let engageDistance = objectManifest.trainerEngageDistance, let gameplayState else {
            return nil
        }

        let playerPosition = gameplayState.playerPosition
        let direction = objectState.facing
        let distance: Int

        switch direction {
        case .up where playerPosition.x == objectState.position.x && playerPosition.y < objectState.position.y:
            distance = objectState.position.y - playerPosition.y
        case .down where playerPosition.x == objectState.position.x && playerPosition.y > objectState.position.y:
            distance = playerPosition.y - objectState.position.y
        case .left where playerPosition.y == objectState.position.y && playerPosition.x < objectState.position.x:
            distance = objectState.position.x - playerPosition.x
        case .right where playerPosition.y == objectState.position.y && playerPosition.x > objectState.position.x:
            distance = playerPosition.x - objectState.position.x
        default:
            return nil
        }

        guard distance > 0, distance <= engageDistance else {
            return nil
        }

        let occupiedTiles = occupiedTileSet(excludingObjectIDs: [objectManifest.id], excludingPlayer: true)
        var current = objectState.position
        var path: [FacingDirection] = []

        for _ in 0..<max(0, distance - 1) {
            let next = translated(current, by: direction)
            guard canActorOccupy(next, from: current, in: map, facing: direction, occupiedTiles: occupiedTiles, reservedTiles: []) else {
                return nil
            }
            path.append(direction)
            current = next
        }

        return current == translated(gameplayState.playerPosition, by: oppositeFacingDirection(of: direction)) ? path : nil
    }

    func isTrainerDefeated(_ manifest: MapObjectManifest) -> Bool {
        guard let battleID = manifest.trainerBattleID,
              let completionFlagID = content.trainerBattle(id: battleID)?.completionFlagID else {
            return false
        }
        return hasFlag(completionFlagID)
    }

    func oppositeFacingDirection(of direction: FacingDirection) -> FacingDirection {
        switch direction {
        case .up: return .down
        case .down: return .up
        case .left: return .right
        case .right: return .left
        }
    }
}
