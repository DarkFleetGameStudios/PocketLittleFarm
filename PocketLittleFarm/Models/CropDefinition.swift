import Foundation

/// Static crop catalog. Timers are real-world durations for offline care.
struct CropDefinition: Identifiable, Hashable, Sendable {
    let id: String
    let displayName: String
    let seedItemId: String
    let harvestItemId: String
    let seedPrice: Int
    let sellPrice: Int
    /// Total grow time when watered on schedule.
    let growDuration: TimeInterval
    /// How often the plant needs water while growing.
    let waterEvery: TimeInterval
    /// Extra time after becoming thirsty before wilt.
    let thirstGrace: TimeInterval
    /// Extra time after wilt before the plant is lost.
    let wiltToLost: TimeInterval
    let harvestYield: Int
    /// Yield multiplier when harvested while wilted (revived path uses full after care).
    let wiltedYieldFactor: Double

    static let all: [CropDefinition] = [
        // Economy: seed cost << harvest value so one good cycle restocks several seeds.
        // Thirst windows are forgiving — Tamagotchi pressure without total wipeouts.
        CropDefinition(
            id: "radish",
            displayName: "Radish",
            seedItemId: "seed_radish",
            harvestItemId: "radish",
            seedPrice: 3,
            sellPrice: 14,
            growDuration: 45 * 60,
            waterEvery: 30 * 60,
            thirstGrace: 45 * 60,
            wiltToLost: 90 * 60,
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
            growDuration: 2 * 60 * 60,
            waterEvery: 60 * 60,
            thirstGrace: 50 * 60,
            wiltToLost: 2 * 60 * 60,
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
            growDuration: 4 * 60 * 60,
            waterEvery: 2 * 60 * 60,
            thirstGrace: 75 * 60,
            wiltToLost: 3 * 60 * 60,
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
            growDuration: 6 * 60 * 60,
            waterEvery: 2.5 * 60 * 60,
            thirstGrace: 90 * 60,
            wiltToLost: 4 * 60 * 60,
            harvestYield: 3,
            wiltedYieldFactor: 0.5
        ),
        CropDefinition(
            id: "pumpkin",
            displayName: "Pumpkin",
            seedItemId: "seed_pumpkin",
            harvestItemId: "pumpkin",
            seedPrice: 16,
            sellPrice: 78,
            growDuration: 14 * 60 * 60,
            waterEvery: 5 * 60 * 60,
            thirstGrace: 3 * 60 * 60,
            wiltToLost: 6 * 60 * 60,
            harvestYield: 1,
            wiltedYieldFactor: 0.5
        ),
    ]

    static let byId: [String: CropDefinition] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
    static let bySeedId: [String: CropDefinition] = Dictionary(uniqueKeysWithValues: all.map { ($0.seedItemId, $0) })

    static func crop(forSeedItemId id: String) -> CropDefinition? { bySeedId[id] }
    static func crop(id: String) -> CropDefinition? { byId[id] }
}
