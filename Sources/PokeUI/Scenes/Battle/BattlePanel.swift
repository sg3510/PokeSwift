import SwiftUI
import PokeDataModel

public struct BattlePanel: View {
    let trainerName: String
    let playerPokemon: PartyPokemonTelemetry
    let enemyPokemon: PartyPokemonTelemetry
    let playerSpriteURL: URL?
    let enemySpriteURL: URL?
    let presentation: BattlePresentationTelemetry

    public init(
        trainerName: String,
        playerPokemon: PartyPokemonTelemetry,
        enemyPokemon: PartyPokemonTelemetry,
        playerSpriteURL: URL?,
        enemySpriteURL: URL?,
        presentation: BattlePresentationTelemetry
    ) {
        self.trainerName = trainerName
        self.playerPokemon = playerPokemon
        self.enemyPokemon = enemyPokemon
        self.playerSpriteURL = playerSpriteURL
        self.enemySpriteURL = enemySpriteURL
        self.presentation = presentation
    }

    public var body: some View {
        GeometryReader { proxy in
            let scale = viewportScale(for: proxy.size)
            let viewportSize = CGSize(
                width: CGFloat(FieldSceneRenderer.viewportPixelSize.width) * scale,
                height: CGFloat(FieldSceneRenderer.viewportPixelSize.height) * scale
            )

            BattleViewportCanvas(
                playerPokemon: playerPokemon,
                enemyPokemon: enemyPokemon,
                playerSpriteURL: playerSpriteURL,
                enemySpriteURL: enemySpriteURL,
                presentation: presentation
            )
            .frame(width: viewportSize.width, height: viewportSize.height)
            .battleScreenEffect(displayScale: scale, presentation: presentation)
            .clipShape(RoundedRectangle(cornerRadius: max(6, scale * 2.5), style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: max(6, scale * 2.5), style: .continuous)
                    .stroke(Color.black.opacity(0.16), lineWidth: max(1, scale * 0.16))
            }
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
    }

    private func viewportScale(for size: CGSize) -> CGFloat {
        let rawScale = min(
            size.width / CGFloat(FieldSceneRenderer.viewportPixelSize.width),
            size.height / CGFloat(FieldSceneRenderer.viewportPixelSize.height)
        )
        guard rawScale.isFinite, rawScale > 0 else {
            return 1
        }
        if rawScale >= 1 {
            return max(1, floor(rawScale))
        }
        return rawScale
    }
}
