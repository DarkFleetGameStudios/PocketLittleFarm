import XCTest
@testable import PocketLittleFarm

final class FarmSimulatorTests: XCTestCase {

    func testGrowingBecomesRipeAfterDuration() {
        var save = SaveGame.fresh(now: Date(timeIntervalSince1970: 1_000_000))
        let now = save.lastSimulatedAt
        // Plant radish on plot 0
        let planted = FarmSimulator.plant(save: save, plotId: 0, seedItemId: "seed_radish", now: now)
        save = planted.0
        XCTAssertEqual(save.plots[0].phase, .growing)

        let crop = CropDefinition.crop(id: "radish")!
        // Stay watered: advance in chunks smaller than waterEvery
        var t = now
        let step = crop.waterEvery * 0.5
        while t.timeIntervalSince(now) < crop.growDuration + 10 {
            t = t.addingTimeInterval(step)
            save = FarmSimulator.water(save: save, plotId: 0, now: t).0
        }
        // Final advance to ensure ripe
        t = now.addingTimeInterval(crop.growDuration + 60)
        save = FarmSimulator.advance(save: save, to: t)
        // May be thirsty if last water was long ago — water once more and advance tiny bit
        if save.plots[0].phase != .ripe {
            save = FarmSimulator.water(save: save, plotId: 0, now: t).0
            save = FarmSimulator.advance(save: save, to: t.addingTimeInterval(1))
        }
        XCTAssertEqual(save.plots[0].phase, .ripe)
    }

    func testThirstLeadsToWilt() {
        var save = SaveGame.fresh(now: Date(timeIntervalSince1970: 2_000_000))
        let now = save.lastSimulatedAt
        save = FarmSimulator.plant(save: save, plotId: 0, seedItemId: "seed_radish", now: now).0
        let crop = CropDefinition.crop(id: "radish")!
        let later = now.addingTimeInterval(crop.waterEvery + crop.thirstGrace + 30)
        save = FarmSimulator.advance(save: save, to: later)
        XCTAssertEqual(save.plots[0].phase, .wilted)
    }

    func testWiltLeadsToLost() {
        var save = SaveGame.fresh(now: Date(timeIntervalSince1970: 3_000_000))
        let now = save.lastSimulatedAt
        save = FarmSimulator.plant(save: save, plotId: 0, seedItemId: "seed_radish", now: now).0
        let crop = CropDefinition.crop(id: "radish")!
        let later = now.addingTimeInterval(crop.waterEvery + crop.thirstGrace + crop.wiltToLost + 60)
        save = FarmSimulator.advance(save: save, to: later)
        XCTAssertEqual(save.plots[0].phase, .lost)
    }

    func testWaterRevivesWilted() {
        var save = SaveGame.fresh(now: Date(timeIntervalSince1970: 4_000_000))
        let now = save.lastSimulatedAt
        save = FarmSimulator.plant(save: save, plotId: 0, seedItemId: "seed_radish", now: now).0
        let crop = CropDefinition.crop(id: "radish")!
        let wiltedAt = now.addingTimeInterval(crop.waterEvery + crop.thirstGrace + 30)
        save = FarmSimulator.advance(save: save, to: wiltedAt)
        XCTAssertEqual(save.plots[0].phase, .wilted)
        save = FarmSimulator.water(save: save, plotId: 0, now: wiltedAt).0
        XCTAssertEqual(save.plots[0].phase, .growing)
    }

    func testChickensGetHungryWithoutFeed() {
        var save = SaveGame.fresh(now: Date(timeIntervalSince1970: 5_000_000))
        let now = save.lastSimulatedAt
        let later = now.addingTimeInterval(FarmBalance.feedInterval + 60)
        save = FarmSimulator.advance(save: save, to: later)
        XCTAssertTrue(save.animals.allSatisfy { $0.mood == .hungry || $0.mood == .neglected })
    }

    func testFeedRestoresContent() {
        var save = SaveGame.fresh(now: Date(timeIntervalSince1970: 6_000_000))
        let now = save.lastSimulatedAt
        let later = now.addingTimeInterval(FarmBalance.feedInterval + 60)
        save = FarmSimulator.advance(save: save, to: later)
        save = FarmSimulator.feedAllChickens(save: save, now: later).0
        XCTAssertTrue(save.animals.allSatisfy { $0.mood == .content })
    }

    func testEggsProduceWhileContent() {
        var save = SaveGame.fresh(now: Date(timeIntervalSince1970: 7_000_000))
        let now = save.lastSimulatedAt
        // Keep fed: advance less than feed interval but more than egg interval
        let later = now.addingTimeInterval(FarmBalance.eggInterval + 30)
        save = FarmSimulator.advance(save: save, to: later)
        let eggs = save.animals.reduce(0) { $0 + $1.pendingProduce }
        XCTAssertGreaterThanOrEqual(eggs, 2) // two hens
    }

    func testDailyStipendGrantsCoinsAndSeeds() {
        var save = SaveGame.fresh(now: Date(timeIntervalSince1970: 8_000_000))
        let day1 = save.lastSimulatedAt
        // Pretend stipend already claimed today
        save.lastDailyGrantDayKey = FarmBalance.dayKey(for: day1)
        let coinsBefore = save.coins
        let seedsBefore = save.inventoryCount(itemId: "seed_radish")

        // Jump to next calendar day
        let day2 = Calendar.current.date(byAdding: .day, value: 1, to: day1)!
        save = FarmSimulator.advance(save: save, to: day2)

        XCTAssertEqual(save.lastDailyGrantDayKey, FarmBalance.dayKey(for: day2))
        XCTAssertEqual(save.coins, coinsBefore + FarmBalance.dailyCoins)
        XCTAssertEqual(save.inventoryCount(itemId: "seed_radish"), seedsBefore + FarmBalance.dailyRadishSeeds)
        XCTAssertNotNil(save.pendingToast)
    }

    func testSoftLockRescueWhenBrokeAndSeedless() {
        var save = SaveGame.fresh(now: Date(timeIntervalSince1970: 9_000_000))
        save.coins = 0
        save.inventory = []
        save.plots = save.plots.map { p in
            var q = p
            q.clearToEmpty()
            return q
        }
        // Already got today's stipend so rescue path is isolated
        save.lastDailyGrantDayKey = FarmBalance.dayKey(for: save.lastSimulatedAt)

        save = FarmSimulator.advance(save: save, to: save.lastSimulatedAt.addingTimeInterval(2))

        XCTAssertGreaterThanOrEqual(save.coins, FarmBalance.bailoutCoins)
        XCTAssertGreaterThanOrEqual(save.inventoryCount(itemId: "seed_radish"), FarmBalance.bailoutRadishSeeds)
    }
}
