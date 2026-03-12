import SwiftUI
import PokeDataModel
import PokeUI

struct FieldPromptOverlay: View {
    let prompt: FieldPromptTelemetry

    var body: some View {
        GameplayHoverCardSurface(padding: 14) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(prompt.options.enumerated()), id: \.offset) { index, option in
                    HStack(spacing: 10) {
                        Text(index == prompt.focusedIndex ? "▶" : " ")
                        Text(option.uppercased())
                        Spacer(minLength: 8)
                    }
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(GameplayFieldStyleTokens.ink.opacity(index == prompt.focusedIndex ? 1 : 0.78))
                }
            }
        }
    }
}
