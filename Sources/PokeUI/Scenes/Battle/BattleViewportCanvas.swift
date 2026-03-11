import SwiftUI
import PokeDataModel

struct BattleViewportCanvas: View {
    let playerPokemon: PartyPokemonTelemetry
    let enemyPokemon: PartyPokemonTelemetry
    let playerSpriteURL: URL?
    let enemySpriteURL: URL?
    let presentation: BattlePresentationTelemetry

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let layout = BattleViewportLayout(size: size)

            ZStack(alignment: .topLeading) {
                battleBackground

                BattleStatusCard(
                    pokemon: enemyPokemon,
                    chrome: .enemy,
                    showsExperience: false,
                    presentation: presentation
                )
                .frame(width: layout.enemyCardSize.width, height: layout.enemyCardSize.height)
                .position(x: layout.enemyCardCenter.x, y: layout.enemyCardCenter.y)
                .opacity(hudOpacity)
                .offset(y: hudOffset)

                BattleStatusCard(
                    pokemon: playerPokemon,
                    chrome: .player,
                    showsExperience: true,
                    presentation: presentation
                )
                .frame(width: layout.playerCardSize.width, height: layout.playerCardSize.height)
                .position(x: layout.playerCardCenter.x, y: layout.playerCardCenter.y)
                .opacity(hudOpacity)
                .offset(y: hudOffset)

                if let enemySpriteURL {
                    PixelAssetView(
                        url: enemySpriteURL,
                        label: enemyPokemon.displayName,
                        whiteIsTransparent: true
                    )
                    .frame(width: layout.enemySpriteSize.width, height: layout.enemySpriteSize.height)
                    .position(enemySpriteCenter(in: layout))
                    .scaleEffect(enemySpriteScale)
                }

                if let playerSpriteURL {
                    PixelAssetView(
                        url: playerSpriteURL,
                        label: playerPokemon.displayName,
                        whiteIsTransparent: true
                    )
                    .frame(width: layout.playerSpriteSize.width, height: layout.playerSpriteSize.height)
                    .position(playerSpriteCenter(in: layout))
                    .scaleEffect(playerSpriteScale)
                }
            }
            .animation(.easeInOut(duration: 0.24), value: presentation.revision)
        }
    }

    private var hudOpacity: Double {
        presentation.uiVisibility == .visible ? 1 : 0
    }

    private var hudOffset: CGFloat {
        presentation.uiVisibility == .visible ? 0 : 14
    }

    private var enemySpriteScale: CGFloat {
        switch presentation.stage {
        case .attackImpact where presentation.activeSide == .enemy:
            return 1.04
        default:
            return 1
        }
    }

    private var playerSpriteScale: CGFloat {
        switch presentation.stage {
        case .attackImpact where presentation.activeSide == .player:
            return 1.04
        default:
            return 1
        }
    }

    private func enemySpriteCenter(in layout: BattleViewportLayout) -> CGPoint {
        let settled = layout.enemySpriteCenter
        switch presentation.stage {
        case .introTransition:
            return CGPoint(x: layout.size.width * 1.22, y: settled.y - 14)
        case .introEnemySendOut:
            return CGPoint(x: settled.x - (layout.size.width * 0.12), y: settled.y - 2)
        case .introPlayerSendOut:
            return CGPoint(x: settled.x + (layout.size.width * 0.04), y: settled.y)
        case .attackWindup where presentation.activeSide == .enemy:
            return CGPoint(x: settled.x - layout.size.width * 0.07, y: settled.y + 2)
        case .attackImpact where presentation.activeSide == .enemy:
            return CGPoint(x: settled.x + layout.size.width * 0.02, y: settled.y)
        case .attackImpact where presentation.activeSide == .player:
            return CGPoint(x: settled.x + layout.size.width * 0.03, y: settled.y - 2)
        default:
            return settled
        }
    }

    private func playerSpriteCenter(in layout: BattleViewportLayout) -> CGPoint {
        let settled = layout.playerSpriteCenter
        switch presentation.stage {
        case .introTransition:
            return CGPoint(x: -layout.size.width * 0.22, y: settled.y + 12)
        case .introEnemySendOut:
            return CGPoint(x: -layout.size.width * 0.12, y: settled.y + 10)
        case .introPlayerSendOut:
            return CGPoint(x: settled.x + (layout.size.width * 0.16), y: settled.y - 10)
        case .attackWindup where presentation.activeSide == .player:
            return CGPoint(x: settled.x + layout.size.width * 0.09, y: settled.y - 4)
        case .attackImpact where presentation.activeSide == .player:
            return CGPoint(x: settled.x - layout.size.width * 0.02, y: settled.y)
        case .attackImpact where presentation.activeSide == .enemy:
            return CGPoint(x: settled.x - layout.size.width * 0.03, y: settled.y + 2)
        default:
            return settled
        }
    }

    private var battleBackground: some View {
        ZStack {
            Rectangle()
                .fill(Color(red: 0.49, green: 0.56, blue: 0.17))

            LinearGradient(
                colors: [
                    Color.white.opacity(0.03),
                    Color.clear,
                    Color.black.opacity(0.04),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

struct BattleViewportLayout {
    let size: CGSize

    var enemyCardSize: CGSize {
        CGSize(width: size.width * 0.38, height: size.height * 0.105)
    }

    var playerCardSize: CGSize {
        CGSize(width: size.width * 0.41, height: size.height * 0.135)
    }

    var enemyCardCenter: CGPoint {
        CGPoint(x: size.width * 0.26, y: size.height * 0.135)
    }

    var playerCardCenter: CGPoint {
        CGPoint(x: size.width * 0.7, y: size.height * 0.6)
    }

    var enemySpriteSize: CGSize {
        CGSize(width: size.width * 0.3, height: size.height * 0.3)
    }

    var playerSpriteSize: CGSize {
        CGSize(width: size.width * 0.28, height: size.height * 0.28)
    }

    var enemySpriteCenter: CGPoint {
        CGPoint(x: size.width * 0.72, y: size.height * 0.3)
    }

    var playerSpriteCenter: CGPoint {
        CGPoint(x: size.width * 0.25, y: size.height * 0.69)
    }
}
