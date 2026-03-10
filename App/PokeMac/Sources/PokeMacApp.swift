import SwiftUI
import PokeCore

@main
struct PokeMacApp: App {
    private static let windowSize = CGSize(width: 1150, height: 800)
    @State private var coordinator = AppCoordinator()

    var body: some Scene {
        WindowGroup {
            RootView(coordinator: coordinator)
        }
        .defaultSize(width: Self.windowSize.width, height: Self.windowSize.height)
        .windowResizability(.contentSize)
        .commands {
            CommandMenu("PokeSwift") {
                Button("Toggle Debug Panel") {
                    coordinator.toggleDebugPanel()
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])
            }
        }
    }
}
