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
            let decoded = try decoder.decode(SaveGame.self, from: data)
            let migrated = migrate(decoded)
            // Always run sim so daily stipend / bailout can unstick a dead farm on launch.
            return FarmSimulator.advance(save: migrated, to: now)
        } catch {
            // Never silently wipe: preserve the unreadable file so nothing is lost and it can
            // be inspected, then start fresh. Tolerant decoding (SaveGame.init(from:)) means we
            // only land here on genuine corruption, not on a missing/added field.
            quarantine(url)
            return .fresh(now: now)
        }
    }

    /// Bring an older save up to the current schema. Field defaults are supplied by
    /// `SaveGame.init(from:)`; this is where any value-transforming migration steps live.
    private static func migrate(_ save: SaveGame) -> SaveGame {
        guard save.version < SaveGame.currentVersion else { return save }
        var s = save
        // (No value transforms needed yet — tolerant decoding fills new fields with defaults.)
        s.version = SaveGame.currentVersion
        return s
    }

    private static func quarantine(_ url: URL) {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        let stamp = Int(Date().timeIntervalSince1970)
        let dead = url.deletingLastPathComponent()
            .appendingPathComponent("savegame.corrupt-\(stamp).json")
        try? FileManager.default.moveItem(at: url, to: dead)
    }

    static func save(_ game: SaveGame) throws {
        let data = try encoder.encode(game)
        let url = fileURL
        let temp = url.appendingPathExtension("tmp")
        try data.write(to: temp, options: .atomic)
        if FileManager.default.fileExists(atPath: url.path) {
            // Keep the last good save as a backup before replacing — cheap insurance against a
            // bad write or a future decode bug.
            let backup = url.deletingLastPathComponent().appendingPathComponent("savegame.bak")
            try? FileManager.default.removeItem(at: backup)
            try? FileManager.default.copyItem(at: url, to: backup)
            _ = try FileManager.default.replaceItemAt(url, withItemAt: temp)
        } else {
            try FileManager.default.moveItem(at: temp, to: url)
        }
    }

    static func delete() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
