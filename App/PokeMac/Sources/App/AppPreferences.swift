import Observation
import PokeCore
import PokeUI

@MainActor
@Observable
final class AppPreferences {
    var appearanceMode: AppAppearanceMode
    var gameBoyShellStyle: GameBoyShellStyle
    var gameplayHDREnabled: Bool
    var musicEnabled: Bool

    private let settingsStore: AppSettingsStore
    private weak var runtime: GameRuntime?

    init(settingsStore: AppSettingsStore = AppSettingsStore()) {
        self.settingsStore = settingsStore
        appearanceMode = settingsStore.appearanceMode
        gameBoyShellStyle = settingsStore.gameBoyShellStyle
        gameplayHDREnabled = settingsStore.gameplayHDREnabled
        musicEnabled = settingsStore.musicEnabled
    }

    func attachRuntime(_ runtime: GameRuntime?) {
        self.runtime = runtime
        runtime?.setMusicEnabled(musicEnabled)
    }

    func cycleAppearanceMode() {
        let nextMode = appearanceMode.nextOptionMode
        appearanceMode = nextMode
        settingsStore.appearanceMode = nextMode
    }

    func setGameBoyShellStyle(_ shellStyle: GameBoyShellStyle) {
        guard gameBoyShellStyle != shellStyle else {
            return
        }

        gameBoyShellStyle = shellStyle
        settingsStore.gameBoyShellStyle = shellStyle
    }

    func toggleGameplayHDREnabled() {
        gameplayHDREnabled.toggle()
        settingsStore.gameplayHDREnabled = gameplayHDREnabled
    }

    func toggleMusicEnabled() {
        let nextValue = musicEnabled == false
        musicEnabled = nextValue
        settingsStore.musicEnabled = nextValue
        runtime?.setMusicEnabled(nextValue)
    }
}
