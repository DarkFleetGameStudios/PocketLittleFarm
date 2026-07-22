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
    /// Accumulated grow time toward ripe. Growth never pauses in v2 — neglect can't kill it.
    var growProgress: TimeInterval
    /// Grow-time spent dry (past `waterEvery` since last drink). Lowers yield, never kills.
    var dryTime: TimeInterval
    /// Time since last watering. Drives the advisory thirsty state and dry-time accrual.
    var sinceWatered: TimeInterval
    /// Time spent ripe (toward past-prime, then compost). Generous — "collect", not "rescue".
    var ripeAge: TimeInterval
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
            dryTime: 0,
            sinceWatered: 0,
            ripeAge: 0,
            plantedAt: nil,
            lastWateredAt: nil
        )
    }

    mutating func clearToEmpty() {
        phase = .empty
        cropId = nil
        growProgress = 0
        dryTime = 0
        sinceWatered = 0
        ripeAge = 0
        plantedAt = nil
        lastWateredAt = nil
    }
}

extension PlotState {
    // Tolerant decoding: older saves (pre-v2, missing dryTime/ripeAge) and any future field
    // must never throw — a thrown decode wipes the whole farm. Living in an extension keeps
    // the memberwise initializer synthesized. Encoding stays auto-synthesized via CodingKeys.
    enum CodingKeys: String, CodingKey {
        case id, row, col, phase, cropId, growProgress, dryTime, sinceWatered, ripeAge, plantedAt, lastWateredAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        row = try c.decodeIfPresent(Int.self, forKey: .row) ?? 0
        col = try c.decodeIfPresent(Int.self, forKey: .col) ?? 0
        phase = try c.decodeIfPresent(PlotPhase.self, forKey: .phase) ?? .empty
        cropId = try c.decodeIfPresent(String.self, forKey: .cropId)
        growProgress = try c.decodeIfPresent(TimeInterval.self, forKey: .growProgress) ?? 0
        dryTime = try c.decodeIfPresent(TimeInterval.self, forKey: .dryTime) ?? 0
        sinceWatered = try c.decodeIfPresent(TimeInterval.self, forKey: .sinceWatered) ?? 0
        ripeAge = try c.decodeIfPresent(TimeInterval.self, forKey: .ripeAge) ?? 0
        plantedAt = try c.decodeIfPresent(Date.self, forKey: .plantedAt)
        lastWateredAt = try c.decodeIfPresent(Date.self, forKey: .lastWateredAt)
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

    static func freshPlots() -> [PlotState] {
        var plots: [PlotState] = []
        var id = 0
        for r in 0..<gridRows {
            for c in 0..<gridCols {
                plots.append(.empty(id: id, row: r, col: c))
                id += 1
            }
        }
        return plots
    }

    static func fresh(now: Date = Date()) -> SaveGame {
        let plots = freshPlots()
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
            // Blend acquire times by quantity so a fresh batch isn't destroyed by old
            // stack-mates (and old items aren't kept alive forever by fresh ones). Without
            // this, spoilInventory drops the whole stack on the oldest member's age.
            let existing = inventory[idx]
            let total = existing.count + count
            let existingRef = existing.acquiredAt.timeIntervalSinceReferenceDate
            let newRef = date.timeIntervalSinceReferenceDate
            let blended = (existingRef * Double(existing.count) + newRef * Double(count)) / Double(total)
            inventory[idx].count = total
            inventory[idx].acquiredAt = Date(timeIntervalSinceReferenceDate: blended)
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

extension SaveGame {
    // Tolerant decoding is the core of save-safety: a save that predates any field — or a
    // future field — must decode with a sensible default instead of throwing, because a
    // thrown decode makes SaveStore fall back to .fresh() and silently wipe the farm.
    // In an extension so the memberwise initializer (used by fresh()) stays synthesized.
    enum CodingKeys: String, CodingKey {
        case version, lastSimulatedAt, coins, inventory, plots, animals, decorations,
             unlockedCropIds, selectedSeedItemId, careStreakDays, lastCareDayKey,
             lastDailyGrantDayKey, settings, hasCompletedOnboarding, pendingToast
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? SaveGame.currentVersion
        lastSimulatedAt = try c.decodeIfPresent(Date.self, forKey: .lastSimulatedAt) ?? Date()
        coins = try c.decodeIfPresent(Int.self, forKey: .coins) ?? 0
        inventory = try c.decodeIfPresent([InventoryStack].self, forKey: .inventory) ?? []
        plots = try c.decodeIfPresent([PlotState].self, forKey: .plots) ?? SaveGame.freshPlots()
        animals = try c.decodeIfPresent([AnimalState].self, forKey: .animals) ?? AnimalState.starterChickens()
        decorations = try c.decodeIfPresent([PlacedDecoration].self, forKey: .decorations) ?? []
        unlockedCropIds = try c.decodeIfPresent([String].self, forKey: .unlockedCropIds) ?? CropDefinition.all.map(\.id)
        selectedSeedItemId = try c.decodeIfPresent(String.self, forKey: .selectedSeedItemId)
        careStreakDays = try c.decodeIfPresent(Int.self, forKey: .careStreakDays) ?? 0
        lastCareDayKey = try c.decodeIfPresent(String.self, forKey: .lastCareDayKey)
        lastDailyGrantDayKey = try c.decodeIfPresent(String.self, forKey: .lastDailyGrantDayKey)
        settings = try c.decodeIfPresent(PlayerSettings.self, forKey: .settings) ?? .default
        hasCompletedOnboarding = try c.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding) ?? false
        pendingToast = try c.decodeIfPresent(String.self, forKey: .pendingToast)
    }
}
