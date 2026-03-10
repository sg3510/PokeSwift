import Foundation

public struct GameSaveMetadata: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let variant: GameVariant
    public let playthroughID: String
    public let playerName: String
    public let locationName: String
    public let badgeCount: Int
    public let playTimeSeconds: Int
    public let savedAt: String

    public init(
        schemaVersion: Int,
        variant: GameVariant,
        playthroughID: String,
        playerName: String,
        locationName: String,
        badgeCount: Int,
        playTimeSeconds: Int,
        savedAt: String
    ) {
        self.schemaVersion = schemaVersion
        self.variant = variant
        self.playthroughID = playthroughID
        self.playerName = playerName
        self.locationName = locationName
        self.badgeCount = badgeCount
        self.playTimeSeconds = playTimeSeconds
        self.savedAt = savedAt
    }
}

public struct GameSaveEnvelope: Codable, Equatable, Sendable {
    public let metadata: GameSaveMetadata
    public let snapshot: GameSaveSnapshot

    public init(metadata: GameSaveMetadata, snapshot: GameSaveSnapshot) {
        self.metadata = metadata
        self.snapshot = snapshot
    }
}

public struct GameSaveSnapshot: Codable, Equatable, Sendable {
    public let mapID: String
    public let playerPosition: TilePoint
    public let facing: FacingDirection
    public let objectStates: [String: GameSaveObjectState]
    public let activeFlags: [String]
    public let money: Int
    public let earnedBadgeIDs: [String]
    public let playerName: String
    public let rivalName: String
    public let playerParty: [GameSavePokemon]
    public let chosenStarterSpeciesID: String?
    public let rivalStarterSpeciesID: String?
    public let pendingStarterSpeciesID: String?
    public let activeMapScriptTriggerID: String?
    public let activeScriptID: String?
    public let activeScriptStep: Int?
    public let playTimeSeconds: Int

    public init(
        mapID: String,
        playerPosition: TilePoint,
        facing: FacingDirection,
        objectStates: [String: GameSaveObjectState],
        activeFlags: [String],
        money: Int,
        earnedBadgeIDs: [String],
        playerName: String,
        rivalName: String,
        playerParty: [GameSavePokemon],
        chosenStarterSpeciesID: String?,
        rivalStarterSpeciesID: String?,
        pendingStarterSpeciesID: String?,
        activeMapScriptTriggerID: String?,
        activeScriptID: String?,
        activeScriptStep: Int?,
        playTimeSeconds: Int
    ) {
        self.mapID = mapID
        self.playerPosition = playerPosition
        self.facing = facing
        self.objectStates = objectStates
        self.activeFlags = activeFlags
        self.money = money
        self.earnedBadgeIDs = earnedBadgeIDs
        self.playerName = playerName
        self.rivalName = rivalName
        self.playerParty = playerParty
        self.chosenStarterSpeciesID = chosenStarterSpeciesID
        self.rivalStarterSpeciesID = rivalStarterSpeciesID
        self.pendingStarterSpeciesID = pendingStarterSpeciesID
        self.activeMapScriptTriggerID = activeMapScriptTriggerID
        self.activeScriptID = activeScriptID
        self.activeScriptStep = activeScriptStep
        self.playTimeSeconds = playTimeSeconds
    }
}

public struct GameSaveObjectState: Codable, Equatable, Sendable {
    public let position: TilePoint
    public let facing: FacingDirection
    public let visible: Bool

    public init(position: TilePoint, facing: FacingDirection, visible: Bool) {
        self.position = position
        self.facing = facing
        self.visible = visible
    }
}

public struct GameSaveMove: Codable, Equatable, Sendable {
    public let id: String
    public let currentPP: Int

    public init(id: String, currentPP: Int) {
        self.id = id
        self.currentPP = currentPP
    }
}

public struct GameSavePokemon: Codable, Equatable, Sendable {
    public let speciesID: String
    public let nickname: String
    public let level: Int
    public let maxHP: Int
    public let currentHP: Int
    public let attack: Int
    public let defense: Int
    public let speed: Int
    public let special: Int
    public let attackStage: Int
    public let defenseStage: Int
    public let accuracyStage: Int
    public let evasionStage: Int
    public let moves: [GameSaveMove]

    public init(
        speciesID: String,
        nickname: String,
        level: Int,
        maxHP: Int,
        currentHP: Int,
        attack: Int,
        defense: Int,
        speed: Int,
        special: Int,
        attackStage: Int,
        defenseStage: Int,
        accuracyStage: Int,
        evasionStage: Int,
        moves: [GameSaveMove]
    ) {
        self.speciesID = speciesID
        self.nickname = nickname
        self.level = level
        self.maxHP = maxHP
        self.currentHP = currentHP
        self.attack = attack
        self.defense = defense
        self.speed = speed
        self.special = special
        self.attackStage = attackStage
        self.defenseStage = defenseStage
        self.accuracyStage = accuracyStage
        self.evasionStage = evasionStage
        self.moves = moves
    }
}

public struct TitleMenuEntryState: Codable, Equatable, Hashable, Sendable {
    public let id: String
    public let label: String
    public let isEnabled: Bool
    public let detail: String?

    public init(id: String, label: String, isEnabled: Bool, detail: String? = nil) {
        self.id = id
        self.label = label
        self.isEnabled = isEnabled
        self.detail = detail
    }
}

public struct RuntimeSaveResult: Codable, Equatable, Sendable {
    public let operation: String
    public let succeeded: Bool
    public let message: String?
    public let timestamp: String

    public init(operation: String, succeeded: Bool, message: String?, timestamp: String) {
        self.operation = operation
        self.succeeded = succeeded
        self.message = message
        self.timestamp = timestamp
    }
}
