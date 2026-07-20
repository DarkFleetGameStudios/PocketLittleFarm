import Foundation

enum PlotPhase: String, Codable, Sendable {
    case empty
    case growing
    case thirsty
    case wilted
    case ripe
    case lost
}

struct PlotState: Codable, Hashable, Identifiable, Sendable {
    var id: Int
    var row: Int
    var col: Int
    var phase: PlotPhase
    var cropId: String?
    /// Accumulated effective grow time (pauses while thirsty/wilted).
    var growProgress: TimeInterval
    /// Time spent in thirsty phase (toward wilt).
    var thirstyAccumulated: TimeInterval
    /// Time spent wilted (toward lost).
    var wiltedAccumulated: TimeInterval
    /// Time since last watering (while growing).
    var sinceWatered: TimeInterval
    var plantedAt: Date?
    var lastWateredAt: Date?

    static func empty(id: Int, row: Int, col: Int) -> PlotState {
        PlotState(
            id: id,
            row: row,
            col: col,
            phase: .empty,
            cropId: nil,
            growProgress: 0,
            thirstyAccumulated: 0,
            wiltedAccumulated: 0,
            sinceWatered: 0,
            plantedAt: nil,
            lastWateredAt: nil
        )
    }

    mutating func clearToEmpty() {
        phase = .empty
        cropId = nil
        growProgress = 0
        thirstyAccumulated = 0
        wiltedAccumulated = 0
        sinceWatered = 0
        plantedAt = nil
        lastWateredAt = nil
    }
}

enum AnimalMood: String, Codable, Sendable {
    case content
    case hungry
    case neglected
}

struct AnimalState: Codable, Hashable, Identifiable, Sendable {
    var id: String
    var kind: String // "chicken"
    var mood: AnimalMood
    var sinceFed: TimeInterval
    var produceProgress: TimeInterval
    var pendingProduce: Int
    var displayName: String

    static func starterChickens() -> [AnimalState] {
        [
            AnimalState(
                id: "hen_1",
                kind: "chicken",
                mood: .content,
                sinceFed: 0,
                produceProgress: 0,
                pendingProduce: 0,
                displayName: "Pip"
            ),
            AnimalState(
                id: "hen_2",
                kind: "chicken",
                mood: .content,
                sinceFed: 0,
                produceProgress: 0,
                pendingProduce: 0,
                displayName: "Dot"
            ),
        ]
    }
}

struct PlacedDecoration: Codable, Hashable, Identifiable, Sendable {
    var id: String
    var decorationId: String
    var row: Int
    var col: Int
}

struct InventoryStack: Codable, Hashable, Sendable {
    var itemId: String
    var count: Int
    /// Earliest acquire time in this stack for spoilage (simplified).
    var acquiredAt: Date
}

struct PlayerSettings: Codable, Hashable, Sendable {
    var soundEnabled: Bool
    var reduceMotion: Bool
    var notificationsEnabled: Bool

    static let `default` = PlayerSettings(
        soundEnabled: true,
        reduceMotion: false,
        notificationsEnabled: false
    )
}

struct SaveGame: Codable, Sendable {
    var version: Int
    var lastSimulatedAt: Date
    var coins: Int
    var inventory: [InventoryStack]
    var plots: [PlotState]
    var animals: [AnimalState]
    var decorations: [PlacedDecoration]
    var unlockedCropIds: [String]
    var selectedSeedItemId: String?
    var careStreakDays: Int
    var lastCareDayKey: String?
    /// Calendar day of last morning stipend (yyyy-MM-dd).
    var lastDailyGrantDayKey: String?
    var settings: PlayerSettings
    var hasCompletedOnboarding: Bool
    /// One-shot toast from sim (daily post, bailout). Not critical if missing on older saves.
    var pendingToast: String?

    static let gridRows = 6
    static let gridCols = 6
    static let currentVersion = 2

    static func fresh(now: Date = Date()) -> SaveGame {
        var plots: [PlotState] = []
        var id = 0
        for r in 0..<gridRows {
            for c in 0..<gridCols {
                plots.append(.empty(id: id, row: r, col: c))
                id += 1
            }
        }
        return SaveGame(
            version: currentVersion,
            lastSimulatedAt: now,
            coins: 55,
            inventory: [
                InventoryStack(itemId: "seed_radish", count: 10, acquiredAt: now),
                InventoryStack(itemId: "seed_lettuce", count: 5, acquiredAt: now),
                InventoryStack(itemId: "seed_tomato", count: 2, acquiredAt: now),
                InventoryStack(itemId: "chicken_feed", count: 5, acquiredAt: now),
            ],
            plots: plots,
            animals: AnimalState.starterChickens(),
            decorations: [],
            unlockedCropIds: CropDefinition.all.map(\.id),
            selectedSeedItemId: "seed_radish",
            careStreakDays: 0,
            lastCareDayKey: nil,
            lastDailyGrantDayKey: FarmBalance.dayKey(for: now),
            settings: .default,
            hasCompletedOnboarding: false,
            pendingToast: nil
        )
    }

    var totalSeedCount: Int {
        CropDefinition.all.reduce(0) { $0 + inventoryCount(itemId: $1.seedItemId) }
    }

    var hasLivingCrops: Bool {
        plots.contains { phase in
            switch phase.phase {
            case .growing, .thirsty, .wilted, .ripe: return true
            case .empty, .lost: return false
            }
        }
    }

    var cheapestSeedPrice: Int {
        CropDefinition.all.map(\.seedPrice).min() ?? 3
    }

    func inventoryCount(itemId: String) -> Int {
        inventory.first(where: { $0.itemId == itemId })?.count ?? 0
    }

    mutating func addItem(_ itemId: String, count: Int, at date: Date) {
        guard count > 0 else { return }
        if let idx = inventory.firstIndex(where: { $0.itemId == itemId }) {
            inventory[idx].count += count
        } else {
            inventory.append(InventoryStack(itemId: itemId, count: count, acquiredAt: date))
        }
    }

    @discardableResult
    mutating func removeItem(_ itemId: String, count: Int) -> Bool {
        guard let idx = inventory.firstIndex(where: { $0.itemId == itemId }) else { return false }
        guard inventory[idx].count >= count else { return false }
        inventory[idx].count -= count
        if inventory[idx].count == 0 {
            inventory.remove(at: idx)
        }
        return true
    }

    var needsAttentionCount: Int {
        let thirstyPlots = plots.filter { $0.phase == .thirsty || $0.phase == .wilted || $0.phase == .ripe }.count
        let hungryAnimals = animals.filter { $0.mood != .content || $0.pendingProduce > 0 }.count
        return thirstyPlots + hungryAnimals
    }
}
