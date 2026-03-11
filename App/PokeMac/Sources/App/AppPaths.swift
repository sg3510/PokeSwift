import Foundation

enum AppPaths {
    static let validationMode: Bool = ProcessInfo.processInfo.environment["POKESWIFT_VALIDATION_MODE"] == "1"

    private static func userDirectory(
        for searchPath: FileManager.SearchPathDirectory,
        fallbackSubpath: String
    ) -> URL {
        let fileManager = FileManager.default
        if let url = try? fileManager.url(
            for: searchPath,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) {
            return url
        }

        return fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent(fallbackSubpath, isDirectory: true)
    }

    private static let applicationSupportRoot: URL = userDirectory(
        for: .applicationSupportDirectory,
        fallbackSubpath: "Application Support"
    )
    .appendingPathComponent("PokeSwift", isDirectory: true)

    private static let cachesRoot: URL = userDirectory(
        for: .cachesDirectory,
        fallbackSubpath: "Caches"
    )
    .appendingPathComponent("PokeSwift", isDirectory: true)

    static let telemetryPort: UInt16 = {
        if let raw = ProcessInfo.processInfo.environment["POKESWIFT_TELEMETRY_PORT"],
           let port = UInt16(raw) {
            return port
        }
        return 9_777
    }()

    static let traceDirectory: URL = {
        if let override = ProcessInfo.processInfo.environment["POKESWIFT_TRACE_DIR"] {
            return URL(fileURLWithPath: override, isDirectory: true)
        }
        return cachesRoot
            .appendingPathComponent("Traces", isDirectory: true)
            .appendingPathComponent("pokemac", isDirectory: true)
    }()

    static let savesDirectory: URL = {
        if let override = ProcessInfo.processInfo.environment["POKESWIFT_SAVE_ROOT"] {
            return URL(fileURLWithPath: override, isDirectory: true)
        }

        return applicationSupportRoot
            .appendingPathComponent("Saves", isDirectory: true)
    }()

    static let primarySaveURL: URL = savesDirectory
        .appendingPathComponent("red-main", isDirectory: false)
        .appendingPathExtension("json")
}
