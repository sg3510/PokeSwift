import PokeCore
import PokeDataModel
import PokeUI

@MainActor
enum GameplayFieldScenePropsFactory {
    static func make(runtime: GameRuntime) -> GameplayFieldSceneProps {
        let snapshot = runtime.currentSnapshot()
        let sidebarProps = GameplaySidebarScenePropsFactory.make(runtime: runtime, party: snapshot.party)

        return GameplayFieldSceneProps(
            map: runtime.currentMapManifest,
            playerPosition: runtime.playerPosition,
            playerFacing: runtime.playerFacing,
            objects: runtime.currentFieldObjects,
            playerSpriteID: runtime.playerSpriteID,
            renderAssets: makeFieldRenderAssets(runtime: runtime),
            initialFieldDisplayStyle: .defaultGameplayStyle,
            dialogueLines: runtime.currentDialoguePage?.lines,
            starterChoiceOptions: runtime.scene == .starterChoice ? runtime.starterChoiceOptions : [],
            starterChoiceFocusedIndex: runtime.starterChoiceFocusedIndex,
            profile: sidebarProps.profile,
            party: sidebarProps.party,
            inventory: sidebarProps.inventory,
            save: sidebarProps.save,
            options: sidebarProps.options
        )
    }
}

@MainActor
private enum GameplaySidebarScenePropsFactory {
    static func make(runtime: GameRuntime, party: PartyTelemetry?) -> GameplaySidebarSceneProps {
        let manifestIndex = GameplaySidebarManifestIndex(runtime: runtime)

        return GameplaySidebarSceneProps(
            profile: GameplaySidebarPropsBuilder.makeProfile(
                trainerName: runtime.playerName,
                locationName: runtime.currentMapManifest?.displayName ?? "Unknown Location",
                scene: runtime.scene,
                playerPosition: runtime.playerPosition,
                facing: runtime.playerPosition == nil ? nil : runtime.playerFacing,
                portrait: makeTrainerPortrait(runtime: runtime),
                money: runtime.playerMoney,
                ownedBadgeIDs: runtime.earnedBadgeIDs
            ),
            party: GameplaySidebarPropsBuilder.makeParty(
                from: party,
                speciesDetailsByID: manifestIndex.speciesDetailsByID,
                moveDisplayNamesByID: manifestIndex.moveDisplayNamesByID
            ),
            inventory: GameplaySidebarPropsBuilder.makeInventory(),
            save: GameplaySidebarPropsBuilder.makeSaveSection(),
            options: GameplaySidebarPropsBuilder.makeOptionsSection()
        )
    }

    private static func makeTrainerPortrait(runtime: GameRuntime) -> TrainerPortraitProps {
        guard let sprite = runtime.content.overworldSprite(id: runtime.playerSpriteID) else {
            return TrainerPortraitProps(label: runtime.playerName, spriteURL: nil, spriteFrame: nil)
        }

        let spriteFrame: PixelRect?
        switch runtime.playerFacing {
        case .down:
            spriteFrame = sprite.facingFrames.down
        case .up:
            spriteFrame = sprite.facingFrames.up
        case .left:
            spriteFrame = sprite.facingFrames.left
        case .right:
            spriteFrame = sprite.facingFrames.right
        }

        return TrainerPortraitProps(
            label: runtime.playerName,
            spriteURL: runtime.content.rootURL.appendingPathComponent(sprite.imagePath),
            spriteFrame: spriteFrame
        )
    }
}

private struct GameplaySidebarSceneProps {
    let profile: TrainerProfileProps
    let party: PartySidebarProps
    let inventory: InventorySidebarProps
    let save: SaveSidebarProps
    let options: OptionsSidebarProps
}

@MainActor
private struct GameplaySidebarManifestIndex {
    let speciesDetailsByID: [String: PartySidebarSpeciesDetails]
    let moveDisplayNamesByID: [String: String]

    init(runtime: GameRuntime) {
        speciesDetailsByID = Dictionary(
            uniqueKeysWithValues: runtime.content.gameplayManifest.species.map { species in
                (
                    species.id,
                    PartySidebarSpeciesDetails(
                        spriteURL: species.battleSprite.map { runtime.content.rootURL.appendingPathComponent($0.frontImagePath) },
                        primaryType: species.primaryType,
                        secondaryType: species.secondaryType,
                        baseHP: species.baseHP,
                        baseAttack: species.baseAttack,
                        baseDefense: species.baseDefense,
                        baseSpeed: species.baseSpeed,
                        baseSpecial: species.baseSpecial
                    )
                )
            }
        )

        moveDisplayNamesByID = Dictionary(
            uniqueKeysWithValues: runtime.content.gameplayManifest.moves.map { move in
                (move.id, move.displayName)
            }
        )
    }
}
