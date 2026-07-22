import Foundation

/// Static crop catalog. Timers are real-world durations for offline care.
///
/// Care model (v2 — FarmTown-solo): a planted crop **always** grows to ripe. Watering never
/// keeps it alive — it only sets *yield*. `waterEvery` is how often watering tops up the yield
/// meter; grow-time spent dry (past `waterEvery` since the last drink) reduces the final
/// harvest, floored at half. Crop choice is the player's tempo: quick crops for active players,
/// slow cash crops for once-a-day players.
struct CropDefinition: Identifiable, Hashable, Sendable {
    let id: String
    let displayName: String
    let seedItemId: String
    let harvestItemId: String
    let seedPrice: Int
    let sellPrice: Int
    /// Total grow time to ripe (real-world).
    let growDuration: TimeInterval
    /// How often watering tops up the yield meter. Being dry past this only lowers yield.
    let waterEvery: TimeInterval
    let harvestYield: Int
    /// Yield multiplier once a ripe crop goes past-prime (left too long after ripening).
    let wiltedYieldFactor: Double

    static let all: [CropDefinition] = [
        // Timers span "quick turn" to "daily cash crop" so the seed menu is the tempo dial.
        // Short crops earn more per hour (reward active play); long crops earn less per hour
        // but are set-and-forget (reward patience) — the FarmTown tradeoff.
        CropDefinition(
            id: "radish",
            displayName: "Radish",
            seedItemId: "seed_radish",
            harvestItemId: "radish",
            seedPrice: 3,
            sellPrice: 14,
            growDuration: 2 * 60 * 60,
            waterEvery: 60 * 60,
            harvestYield: 3,
            wiltedYieldFactor: 0.5
        ),
        CropDefinition(
            id: "lettuce",
            displayName: "Lettuce",
            seedItemId: "seed_lettuce",
            harvestItemId: "lettuce",
            seedPrice: 5,
            sellPrice: 20,
            growDuration: 4 * 60 * 60,
            waterEvery: 2 * 60 * 60,
            harvestYield: 3,
            wiltedYieldFactor: 0.5
        ),
        CropDefinition(
            id: "tomato",
            displayName: "Tomato",
            seedItemId: "seed_tomato",
            harvestItemId: "tomato",
            seedPrice: 8,
            sellPrice: 34,
            growDuration: 8 * 60 * 60,
            waterEvery: 3 * 60 * 60,
            harvestYield: 3,
            wiltedYieldFactor: 0.5
        ),
        CropDefinition(
            id: "corn",
            displayName: "Corn",
            seedItemId: "seed_corn",
            harvestItemId: "corn",
            seedPrice: 10,
            sellPrice: 42,
            growDuration: 12 * 60 * 60,
            waterEvery: 4 * 60 * 60,
            harvestYield: 4,
            wiltedYieldFactor: 0.5
        ),
        CropDefinition(
            id: "pumpkin",
            displayName: "Pumpkin",
            seedItemId: "seed_pumpkin",
            harvestItemId: "pumpkin",
            seedPrice: 16,
            sellPrice: 130,
            growDuration: 24 * 60 * 60,
            waterEvery: 8 * 60 * 60,
            harvestYield: 2,
            wiltedYieldFactor: 0.5
        ),
    ]

    static let byId: [String: CropDefinition] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
    static let bySeedId: [String: CropDefinition] = Dictionary(uniqueKeysWithValues: all.map { ($0.seedItemId, $0) })

    static func crop(forSeedItemId id: String) -> CropDefinition? { bySeedId[id] }
    static func crop(id: String) -> CropDefinition? { byId[id] }
}
