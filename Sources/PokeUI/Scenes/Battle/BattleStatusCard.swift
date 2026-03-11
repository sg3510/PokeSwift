import SwiftUI
import PokeDataModel

struct BattleStatusCard: View {
    let pokemon: PartyPokemonTelemetry
    let chrome: Chrome
    let showsExperience: Bool

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let horizontalPadding = max(8, size.width * 0.035)
            let topPadding = max(4, size.height * 0.05)
            let bottomPadding = max(4, size.height * 0.05)
            let topInset = max(5, size.height * 0.12)
            let pixelNameScale: CGFloat = 0.9
            let pixelMetaScale: CGFloat = 0.9
            let cardShape = RoundedRectangle(cornerRadius: 16, style: .continuous)

            VStack(alignment: .leading, spacing: max(4, size.height * 0.045)) {
                Color.clear
                    .frame(height: topInset)

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    CombatPixelText(
                        pokemon.displayName.uppercased(),
                        color: FieldRetroPalette.ink,
                        primaryScale: pixelNameScale,
                        minimumScale: pixelNameScale,
                        fallbackFont: .system(size: max(14, size.height * 0.28), weight: .bold, design: .monospaced)
                    )

                    Spacer(minLength: 8)

                    CombatPixelText(
                        "LV\(pokemon.level)",
                        color: FieldRetroPalette.ink.opacity(0.74),
                        primaryScale: pixelMetaScale,
                        alignment: .trailing,
                        fallbackFont: .system(size: max(12, size.height * 0.2), weight: .bold, design: .monospaced)
                    )
                }

                HStack(alignment: .center, spacing: 10) {
                    CombatPixelText(
                        "HP",
                        color: FieldRetroPalette.ink.opacity(0.74),
                        primaryScale: pixelMetaScale,
                        fallbackFont: .system(size: max(10, size.height * 0.17), weight: .bold, design: .monospaced)
                    )

                    BattleHPBar(currentHP: pokemon.currentHP, maxHP: pokemon.maxHP)
                        .frame(maxWidth: .infinity)
                        .frame(height: max(10, size.height * 0.14))
                }

                if showsExperience {
                    HStack(alignment: .center, spacing: 10) {
                        CombatPixelText(
                            "EXP",
                            color: FieldRetroPalette.ink.opacity(0.74),
                            primaryScale: pixelMetaScale,
                            fallbackFont: .system(size: max(10, size.height * 0.17), weight: .bold, design: .monospaced)
                        )

                        BattleExperienceBar(experience: pokemon.experience)
                            .frame(maxWidth: .infinity)
                            .frame(height: max(8, size.height * 0.11))
                    }
                }
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.top, topPadding)
            .padding(.bottom, bottomPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(chrome.backgroundTint, in: cardShape)
            .overlay {
                cardShape
                    .stroke(.white.opacity(0.2), lineWidth: 1)
                    .padding(3)
            }
            .glassEffect(.regular.tint(chrome.tint), in: cardShape)
            .shadow(color: .black.opacity(0.08), radius: 16, y: 8)
        }
    }
}

extension BattleStatusCard {
    enum Chrome {
        case enemy
        case player

        var tint: Color {
            switch self {
            case .enemy:
                return Color(red: 0.92, green: 0.96, blue: 0.84).opacity(0.42)
            case .player:
                return Color(red: 0.78, green: 0.9, blue: 0.76).opacity(0.46)
            }
        }

        var backgroundTint: Color {
            switch self {
            case .enemy:
                return Color.white.opacity(0.18)
            case .player:
                return Color(red: 0.86, green: 0.93, blue: 0.8).opacity(0.22)
            }
        }
    }
}
