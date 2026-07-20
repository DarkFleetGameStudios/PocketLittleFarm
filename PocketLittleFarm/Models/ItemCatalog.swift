import Foundation

enum ItemKind: String, Codable, Sendable {
    case seed
    case harvest
    case animalProduct
    case feed
    case decoration
}

struct ItemDefinition: Identifiable, Hashable, Sendable {
    let id: String
    let displayName: String
    let kind: ItemKind
    let sellPrice: Int
    let buyPrice: Int?
    /// Soft spoilage for harvested goods sitting in inventory (0 = never).
    let spoilAfter: TimeInterval

    static let feed = ItemDefinition(
        id: "chicken_feed",
        displayName: "Chicken Feed",
        kind: .feed,
        sellPrice: 1,
        buyPrice: 4,
        spoilAfter: 0
    )

    static let egg = ItemDefinition(
        id: "egg",
        displayName: "Egg",
        kind: .animalProduct,
        sellPrice: 14,
        buyPrice: nil,
        spoilAfter: 12 * 60 * 60
    )

    static var all: [ItemDefinition] {
        var items: [ItemDefinition] = [.feed, .egg]
        for crop in CropDefinition.all {
            items.append(
                ItemDefinition(
                    id: crop.seedItemId,
                    displayName: "\(crop.displayName) Seeds",
                    kind: .seed,
                    sellPrice: max(1, crop.seedPrice / 3),
                    buyPrice: crop.seedPrice,
                    spoilAfter: 0
                )
            )
            items.append(
                ItemDefinition(
                    id: crop.harvestItemId,
                    displayName: crop.displayName,
                    kind: .harvest,
                    sellPrice: crop.sellPrice,
                    buyPrice: nil,
                    spoilAfter: 12 * 60 * 60
                )
            )
        }
        for deco in DecorationDefinition.all {
            items.append(
                ItemDefinition(
                    id: deco.id,
                    displayName: deco.displayName,
                    kind: .decoration,
                    sellPrice: max(1, deco.price / 4),
                    buyPrice: deco.price,
                    spoilAfter: 0
                )
            )
        }
        return items
    }

    static let byId: [String: ItemDefinition] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

    static func item(id: String) -> ItemDefinition? { byId[id] }
}

struct DecorationDefinition: Identifiable, Hashable, Sendable {
    let id: String
    let displayName: String
    let price: Int
    let emoji: String

    static let all: [DecorationDefinition] = [
        .init(id: "deco_flower_pot", displayName: "Flower Pot", price: 20, emoji: "🪴"),
        .init(id: "deco_scarecrow", displayName: "Scarecrow", price: 40, emoji: "Scarecrow"),
        .init(id: "deco_bench", displayName: "Garden Bench", price: 35, emoji: "🪑"),
        .init(id: "deco_lantern", displayName: "Lantern", price: 30, emoji: "lantern"),
        .init(id: "deco_wagon", displayName: "Little Wagon", price: 55, emoji: "wagon"),
        .init(id: "deco_well", displayName: "Wishing Well", price: 80, emoji: "well"),
        .init(id: "deco_path_stone", displayName: "Stone Path", price: 15, emoji: "stone"),
        .init(id: "deco_fence_rose", displayName: "Rose Fence", price: 45, emoji: "rose"),
    ]

    static let byId: [String: DecorationDefinition] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
}
