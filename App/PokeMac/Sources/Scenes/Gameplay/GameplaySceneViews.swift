import SwiftUI
import PokeCore
import PokeDataModel
import PokeUI

struct GameplayFieldSceneProps {
    let map: MapManifest?
    let playerPosition: TilePoint?
    let playerFacing: FacingDirection
    let objects: [FieldObjectRenderState]
    let playerSpriteID: String
    let renderAssets: FieldRenderAssets?
    let initialFieldDisplayStyle: FieldDisplayStyle
    let dialogueLines: [String]?
    let starterChoiceOptions: [SpeciesManifest]
    let starterChoiceFocusedIndex: Int
    let profile: TrainerProfileProps
    let party: PartySidebarProps
    let inventory: InventorySidebarProps
    let save: SaveSidebarProps
    let options: OptionsSidebarProps
}

struct BattleSceneProps {
    let trainerName: String
    let phase: String
    let textLines: [String]
    let playerPokemon: PartyPokemonTelemetry
    let enemyPokemon: PartyPokemonTelemetry
    let moveSlots: [BattleMoveSlotTelemetry]
    let focusedMoveIndex: Int
    let playerSpriteURL: URL?
    let enemySpriteURL: URL?
}

struct PlaceholderSceneProps {
    let title: String?
}

struct GameplayFieldScene: View {
    let props: GameplayFieldSceneProps
    @State private var fieldDisplayStyle: FieldDisplayStyle

    init(props: GameplayFieldSceneProps) {
        self.props = props
        _fieldDisplayStyle = State(initialValue: props.initialFieldDisplayStyle)
    }

    var body: some View {
        GameBoyScreen(style: .fieldShell) {
            GameplayFieldShell(
                profile: props.profile,
                party: props.party,
                inventory: props.inventory,
                save: props.save,
                options: props.options,
                fieldDisplayStyle: $fieldDisplayStyle
            ) {
                FieldMapStage {
                    mapStageContent
                } footer: {
                    if let dialogueLines = props.dialogueLines {
                        DialogueBoxView(lines: dialogueLines)
                            .frame(maxWidth: 760)
                    }
                } overlayContent: {
                    if props.starterChoiceOptions.isEmpty == false {
                        StarterChoicePanel(
                            options: props.starterChoiceOptions,
                            focusedIndex: props.starterChoiceFocusedIndex
                        )
                        .frame(width: 420)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var mapStageContent: some View {
        if let map = props.map,
           let playerPosition = props.playerPosition {
            FieldMapView(
                map: map,
                playerPosition: playerPosition,
                playerFacing: props.playerFacing,
                objects: props.objects,
                playerSpriteID: props.playerSpriteID,
                renderAssets: props.renderAssets,
                displayStyle: fieldDisplayStyle
            )
        } else {
            VStack(spacing: 14) {
                Text("Field data unavailable")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text("The runtime has not produced a map payload for this scene yet.")
                    .font(.system(size: 16, weight: .medium, design: .monospaced))
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(.black.opacity(0.78))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct BattleScene: View {
    let props: BattleSceneProps

    var body: some View {
        GameBoyScreen {
            BattlePanel(
                trainerName: props.trainerName,
                phase: props.phase,
                textLines: props.textLines,
                playerPokemon: props.playerPokemon,
                enemyPokemon: props.enemyPokemon,
                moveSlots: props.moveSlots,
                focusedMoveIndex: props.focusedMoveIndex,
                playerSpriteURL: props.playerSpriteURL,
                enemySpriteURL: props.enemySpriteURL
            )
            .padding(36)
        }
    }
}

struct PlaceholderScene: View {
    let props: PlaceholderSceneProps

    var body: some View {
        GameBoyScreen {
            GameBoyPanel {
                VStack(spacing: 16) {
                    Text(props.title ?? "Placeholder")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.black)
                    Text("This route is intentionally reserved for Milestone 3 and beyond.")
                        .foregroundStyle(.black.opacity(0.64))
                    Text("Press Escape or X to return to the title menu.")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.black.opacity(0.85))
                }
                .padding(22)
            }
            .frame(width: 580)
        }
    }
}
