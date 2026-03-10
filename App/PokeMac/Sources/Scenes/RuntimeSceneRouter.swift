import Observation
import SwiftUI
import PokeCore
import PokeDataModel
import PokeUI

struct RuntimeSceneRouter: View {
    @Bindable var runtime: GameRuntime

    var body: some View {
        switch runtime.scene {
        case .launch:
            LaunchScene()
        case .splash:
            SplashView(rootURL: runtime.content.rootURL)
        case .titleAttract:
            TitleAttractView(rootURL: runtime.content.rootURL)
        case .titleMenu:
            TitleMenuScene(
                props: .init(
                    rootURL: runtime.content.rootURL,
                    entries: runtime.menuEntries,
                    saveMetadata: runtime.currentSaveMetadata,
                    focusedIndex: runtime.focusedIndex
                )
            )
        case .field, .dialogue, .scriptedSequence, .starterChoice, .battle:
            if let gameplaySceneProps = GameplayScenePropsFactory.make(runtime: runtime) {
                GameplayScene(props: gameplaySceneProps)
            }
        case .placeholder:
            PlaceholderScene(props: .init(title: runtime.placeholderTitle))
        }
    }
}

private struct LaunchScene: View {
    var body: some View {
        GameBoyScreen {
            Text("PokeMac")
                .font(.system(size: 48, weight: .black, design: .rounded))
                .foregroundStyle(.black)
        }
    }
}
