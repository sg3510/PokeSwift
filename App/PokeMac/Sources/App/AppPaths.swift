import Foundation

enum AppPaths {
    static let validationMode: Bool = ProcessInfo.processInfo.environment["POKESWIFT_VALIDATION_MODE"] == "1"

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
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
            .appendingPathComponent(".runtime-traces/pokemac", isDirectory: true)
    }()

    static let savesDirectory: URL = {
        if let override = ProcessInfo.processInfo.environment["POKESWIFT_SAVE_ROOT"] {
            return URL(fileURLWithPath: override, isDirectory: true)
        }

        if let applicationSupport = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) {
            return applicationSupport
                .appendingPathComponent("PokeSwift", isDirectory: true)
                .appendingPathComponent("Saves", isDirectory: true)
        }

        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
            .appendingPathComponent(".runtime-traces/pokemac/saves", isDirectory: true)
    }()

    static let primarySaveURL: URL = savesDirectory
        .appendingPathComponent("red-main", isDirectory: false)
        .appendingPathExtension("json")
}
