import SwiftUI
import PokeCore
import PokeDataModel
import PokeUI

struct GameplaySceneProps {
    let viewport: GameplayViewportProps
    let sidebarMode: GameplaySidebarMode
    let onSidebarAction: ((String) -> Void)?
    let initialFieldDisplayStyle: FieldDisplayStyle
}

enum GameplayViewportProps {
    case field(GameplayFieldViewportProps)
    case battle(BattleViewportProps)
}

struct GameplayFieldViewportProps {
    let map: MapManifest?
    let playerPosition: TilePoint?
    let playerFacing: FacingDirection
    let playerStepDuration: TimeInterval
    let objects: [FieldObjectRenderState]
    let playerSpriteID: String
    let renderAssets: FieldRenderAssets?
    let fieldTransition: FieldTransitionTelemetry?
    let dialogueLines: [String]?
    let starterChoiceOptions: [SpeciesManifest]
    let starterChoiceFocusedIndex: Int
}

struct BattleViewportProps {
    let trainerName: String
    let textLines: [String]
    let playerPokemon: PartyPokemonTelemetry
    let enemyPokemon: PartyPokemonTelemetry
    let playerSpriteURL: URL?
    let enemySpriteURL: URL?
}

struct PlaceholderSceneProps {
    let title: String?
}

struct GameplayScene: View {
    let props: GameplaySceneProps
    @State private var fieldDisplayStyle: FieldDisplayStyle
    @State private var isLoadConfirmationPresented = false

    init(props: GameplaySceneProps) {
        self.props = props
        _fieldDisplayStyle = State(initialValue: props.initialFieldDisplayStyle)
    }

    var body: some View {
        GameBoyScreen(style: .fieldShell) {
            GameplayShell(
                sidebarMode: props.sidebarMode,
                onSidebarAction: handleSidebarAction(_:),
                fieldDisplayStyle: $fieldDisplayStyle
            ) {
                stage
            }
        }
        .confirmationDialog(
            "Load saved game?",
            isPresented: $isLoadConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Load Save", role: .destructive) {
                props.onSidebarAction?("load")
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This replaces the current in-memory progress with the last saved game.")
        }
    }

    @ViewBuilder
    private var stage: some View {
        switch props.viewport {
        case let .field(fieldProps):
            FieldMapStage {
                fieldMapStageContent(fieldProps)
            } footer: {
                if let dialogueLines = fieldProps.dialogueLines {
                    DialogueBoxView(lines: dialogueLines)
                        .frame(maxWidth: 760)
                }
            } overlayContent: {
                if fieldProps.starterChoiceOptions.isEmpty == false {
                    StarterChoicePanel(
                        options: fieldProps.starterChoiceOptions,
                        focusedIndex: fieldProps.starterChoiceFocusedIndex
                    )
                    .frame(width: 420)
                }
            }
        case let .battle(battleProps):
            BattleViewportStage {
                BattlePanel(
                    trainerName: battleProps.trainerName,
                    playerPokemon: battleProps.playerPokemon,
                    enemyPokemon: battleProps.enemyPokemon,
                    playerSpriteURL: battleProps.playerSpriteURL,
                    enemySpriteURL: battleProps.enemySpriteURL,
                    displayStyle: fieldDisplayStyle
                )
            } footer: {
                DialogueBoxView(
                    title: "Battle",
                    lines: battleProps.textLines.isEmpty ? ["Pick the next move."] : battleProps.textLines
                )
                .frame(maxWidth: 760)
            }
        }
    }

    @ViewBuilder
    private func fieldMapStageContent(_ props: GameplayFieldViewportProps) -> some View {
        if let map = props.map,
           let playerPosition = props.playerPosition {
            FieldMapView(
                map: map,
                playerPosition: playerPosition,
                playerFacing: props.playerFacing,
                playerStepDuration: props.playerStepDuration,
                objects: props.objects,
                playerSpriteID: props.playerSpriteID,
                renderAssets: props.renderAssets,
                transition: props.fieldTransition,
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

    private func handleSidebarAction(_ actionID: String) {
        if actionID == "load" {
            isLoadConfirmationPresented = true
            return
        }
        props.onSidebarAction?(actionID)
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
