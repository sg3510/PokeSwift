import PokeDataModel

extension GameRuntime {
    func currentMapObjectManifest(id: String) -> MapObjectManifest? {
        currentMapManifest?.objects.first { $0.id == id }
    }

    func objectManifest(id: String) -> MapObjectManifest? {
        content.gameplayManifest.maps.lazy
            .flatMap(\.objects)
            .first { $0.id == id }
    }

    func ensureObjectStateExists(_ objectID: String, in gameplayState: inout GameplayState) {
        guard gameplayState.objectStates[objectID] == nil, let object = objectManifest(id: objectID) else {
            return
        }
        gameplayState.objectStates[objectID] = RuntimeObjectState(
            position: object.position,
            facing: object.facing,
            visible: object.visibleByDefault,
            movementMode: nil,
            idleStepIndex: 0
        )
    }

    func resetObjectStateToManifest(_ objectID: String, in gameplayState: inout GameplayState) {
        guard let object = objectManifest(id: objectID) else {
            return
        }
        gameplayState.objectStates[objectID] = RuntimeObjectState(
            position: object.position,
            facing: object.facing,
            visible: object.visibleByDefault,
            movementMode: nil,
            idleStepIndex: 0
        )
    }
}
