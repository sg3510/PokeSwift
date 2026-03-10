import Foundation
import PokeDataModel

public protocol SaveStore: Sendable {
    func hasSaveFile() -> Bool
    func loadMetadata() throws -> GameSaveMetadata?
    func loadSave() throws -> GameSaveEnvelope?
    func save(_ envelope: GameSaveEnvelope) throws
    func deleteSave() throws
}
