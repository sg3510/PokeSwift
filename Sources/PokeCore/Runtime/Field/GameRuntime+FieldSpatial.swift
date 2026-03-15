import PokeDataModel

struct ResolvedFieldStep {
    let map: MapManifest
    let point: TilePoint
}

extension GameRuntime {
    func occupiedTileSet(excludingObjectIDs: Set<String>, excludingPlayer: Bool) -> Set<TilePoint> {
        guard let gameplayState, let map = currentMapManifest else { return [] }
        var occupied: Set<TilePoint> = []
        if excludingPlayer == false {
            occupied.insert(gameplayState.playerPosition)
        }
        for object in map.objects where excludingObjectIDs.contains(object.id) == false {
            guard let objectState = gameplayState.objectStates[object.id], objectState.visible else { continue }
            occupied.insert(objectState.position)
        }
        return occupied
    }

    func canActorOccupy(
        _ nextPoint: TilePoint,
        from currentPoint: TilePoint,
        in map: MapManifest,
        facing: FacingDirection,
        occupiedTiles: Set<TilePoint>,
        reservedTiles: Set<TilePoint>
    ) -> Bool {
        guard isWithinFieldBounds(nextPoint, in: map) else {
            return false
        }
        guard occupiedTiles.contains(nextPoint) == false, reservedTiles.contains(nextPoint) == false else {
            return false
        }
        return tilesAllowFieldTraversal(from: currentPoint, to: nextPoint, in: map, facing: facing)
    }

    func shortestPath(
        from start: TilePoint,
        to goal: TilePoint,
        in map: MapManifest,
        ignoringObjectID: String
    ) -> [FacingDirection]? {
        if start == goal {
            return []
        }

        var queue: [TilePoint] = [start]
        var queueIndex = 0
        var visited: Set<TilePoint> = [start]
        var previous: [TilePoint: (TilePoint, FacingDirection)] = [:]
        let occupied = occupiedTileSet(excludingObjectIDs: [ignoringObjectID], excludingPlayer: false)

        while queueIndex < queue.count {
            let current = queue[queueIndex]
            queueIndex += 1
            for direction in FacingDirection.allCases {
                let next = translated(current, by: direction)
                guard visited.contains(next) == false else { continue }
                guard canActorOccupy(
                    next,
                    from: current,
                    in: map,
                    facing: direction,
                    occupiedTiles: occupied.subtracting([start]),
                    reservedTiles: []
                ) else {
                    continue
                }
                visited.insert(next)
                previous[next] = (current, direction)
                if next == goal {
                    return reconstructedPath(goal: goal, previous: previous)
                }
                queue.append(next)
            }
        }

        return nil
    }

    func reconstructedPath(
        goal: TilePoint,
        previous: [TilePoint: (TilePoint, FacingDirection)]
    ) -> [FacingDirection] {
        var path: [FacingDirection] = []
        var cursor = goal
        while let entry = previous[cursor] {
            path.append(entry.1)
            cursor = entry.0
        }
        return path.reversed()
    }

    func isWithinFieldBounds(_ point: TilePoint, in map: MapManifest) -> Bool {
        point.x >= 0 && point.y >= 0 && point.x < map.stepWidth && point.y < map.stepHeight
    }

    func tilesAllowFieldTraversal(
        from currentPoint: TilePoint,
        to nextPoint: TilePoint,
        in map: MapManifest,
        facing: FacingDirection
    ) -> Bool {
        guard let tileset = content.tileset(id: map.tileset),
              let currentTileID = collisionTileID(at: currentPoint, in: map),
              let nextTileID = collisionTileID(at: nextPoint, in: map) else {
            return true
        }

        let passableTileIDs = Set(tileset.collision.passableTileIDs)
        let ledgeAllowsStep = tileset.collision.ledges.contains {
            $0.facing == facing && $0.standingTileID == currentTileID && $0.ledgeTileID == nextTileID
        }

        guard passableTileIDs.contains(nextTileID) || ledgeAllowsStep else {
            return false
        }

        return tileset.collision.tilePairCollisions.contains(where: {
            ($0.fromTileID == currentTileID && $0.toTileID == nextTileID) ||
                ($0.fromTileID == nextTileID && $0.toTileID == currentTileID)
        }) == false
    }

    func canMove(from currentPoint: TilePoint, to nextPoint: TilePoint, in map: MapManifest, facing: FacingDirection) -> Bool {
        resolveFieldStep(
            from: currentPoint,
            to: nextPoint,
            in: map,
            gameplayState: gameplayState,
            facing: facing
        ) != nil
    }

    func collisionTileID(at point: TilePoint, in map: MapManifest) -> Int? {
        guard isWithinFieldBounds(point, in: map) else {
            return nil
        }
        let index = (point.y * map.stepWidth) + point.x
        guard map.stepCollisionTileIDs.indices.contains(index) else { return nil }
        return map.stepCollisionTileIDs[index]
    }

    func resolveFieldStep(
        from currentPoint: TilePoint,
        to nextPoint: TilePoint,
        in map: MapManifest,
        gameplayState: GameplayState?,
        facing: FacingDirection
    ) -> ResolvedFieldStep? {
        if (0..<map.stepWidth).contains(nextPoint.x), (0..<map.stepHeight).contains(nextPoint.y) {
            guard canOccupyFieldPoint(nextPoint, from: currentPoint, in: map, mapID: map.id, gameplayState: gameplayState, facing: facing) else {
                return nil
            }
            return ResolvedFieldStep(map: map, point: nextPoint)
        }

        guard let connectionDestination = connectionDestination(for: nextPoint, from: map, facing: facing) else {
            return nil
        }
        guard canOccupyFieldPoint(
            connectionDestination.point,
            from: connectionDestination.originPoint,
            in: connectionDestination.map,
            mapID: connectionDestination.map.id,
            gameplayState: gameplayState,
            facing: facing
        ) else {
            return nil
        }
        return ResolvedFieldStep(map: connectionDestination.map, point: connectionDestination.point)
    }

    func canOccupyFieldPoint(
        _ nextPoint: TilePoint,
        from currentPoint: TilePoint,
        in map: MapManifest,
        mapID: String,
        gameplayState: GameplayState?,
        facing: FacingDirection
    ) -> Bool {
        guard isWithinFieldBounds(nextPoint, in: map) else {
            return false
        }

        if visibleObjectPositions(on: mapID, gameplayState: gameplayState).contains(nextPoint) {
            return false
        }
        return tilesAllowFieldTraversal(from: currentPoint, to: nextPoint, in: map, facing: facing)
    }

    func visibleObjectPositions(on mapID: String, gameplayState: GameplayState?) -> Set<TilePoint> {
        guard let gameplayState, let map = content.map(id: mapID) else { return [] }
        return Set(map.objects.compactMap { object in
            guard gameplayState.objectStates[object.id]?.visible ?? object.visibleByDefault else { return nil }
            return gameplayState.objectStates[object.id]?.position ?? object.position
        })
    }

    func connectionDestination(
        for attemptedPoint: TilePoint,
        from map: MapManifest,
        facing: FacingDirection
    ) -> (map: MapManifest, point: TilePoint, originPoint: TilePoint)? {
        guard let connection = map.connections.first(where: { $0.direction == mapConnectionDirection(for: facing) }),
              let targetMap = content.map(id: connection.targetMapID) else {
            return nil
        }

        switch facing {
        case .up:
            let targetX = attemptedPoint.x - (connection.offset * 2)
            guard (0..<targetMap.stepWidth).contains(targetX) else { return nil }
            return (
                map: targetMap,
                point: .init(x: targetX, y: targetMap.stepHeight - 1),
                originPoint: .init(x: targetX, y: targetMap.stepHeight)
            )
        case .down:
            let targetX = attemptedPoint.x - (connection.offset * 2)
            guard (0..<targetMap.stepWidth).contains(targetX) else { return nil }
            return (
                map: targetMap,
                point: .init(x: targetX, y: 0),
                originPoint: .init(x: targetX, y: -1)
            )
        case .left:
            let targetY = attemptedPoint.y - (connection.offset * 2)
            guard (0..<targetMap.stepHeight).contains(targetY) else { return nil }
            return (
                map: targetMap,
                point: .init(x: targetMap.stepWidth - 1, y: targetY),
                originPoint: .init(x: targetMap.stepWidth, y: targetY)
            )
        case .right:
            let targetY = attemptedPoint.y - (connection.offset * 2)
            guard (0..<targetMap.stepHeight).contains(targetY) else { return nil }
            return (
                map: targetMap,
                point: .init(x: 0, y: targetY),
                originPoint: .init(x: -1, y: targetY)
            )
        }
    }

    func mapConnectionDirection(for facing: FacingDirection) -> MapConnectionDirection {
        switch facing {
        case .up: return .north
        case .down: return .south
        case .left: return .west
        case .right: return .east
        }
    }
}
