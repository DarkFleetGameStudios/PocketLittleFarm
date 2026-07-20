import Foundation

enum SaveStore {
    private static let fileName = "savegame.json"

    private static var fileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = dir.appendingPathComponent("PocketLittleFarm", isDirectory: true)
        if !FileManager.default.fileExists(atPath: appDir.path) {
            try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        }
        return appDir.appendingPathComponent(fileName)
    }

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    static func load(now: Date = Date()) -> SaveGame {
        let url = fileURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            return .fresh(now: now)
        }
        do {
            let data = try Data(contentsOf: url)
            var save = try decoder.decode(SaveGame.self, from: data)
            if save.version < SaveGame.currentVersion {
                save.version = SaveGame.currentVersion
                // Older saves may lack economy fields; decoding uses defaults via optional/missing keys.
            }
            // Always run sim so daily stipend / bailout can unstick a dead farm on launch.
            return FarmSimulator.advance(save: save, to: now)
        } catch {
            return .fresh(now: now)
        }
    }

    static func save(_ game: SaveGame) throws {
        let data = try encoder.encode(game)
        let url = fileURL
        let temp = url.appendingPathExtension("tmp")
        try data.write(to: temp, options: .atomic)
        if FileManager.default.fileExists(atPath: url.path) {
            _ = try FileManager.default.replaceItemAt(url, withItemAt: temp)
        } else {
            try FileManager.default.moveItem(at: temp, to: url)
        }
    }

    static func delete() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
