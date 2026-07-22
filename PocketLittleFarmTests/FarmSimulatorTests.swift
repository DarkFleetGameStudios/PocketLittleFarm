import XCTest
@testable import PocketLittleFarm

final class FarmSimulatorTests: XCTestCase {

    // MARK: - Growth (v2: neglect never kills; watering sets yield)

    func testGrowingBecomesRipeAfterDuration() {
        var save = SaveGame.fresh(now: Date(timeIntervalSince1970: 1_000_000))
        let now = save.lastSimulatedAt
        save = FarmSimulator.plant(save: save, plotId: 0, seedItemId: "seed_radish", now: now).0
        XCTAssertEqual(save.plots[0].phase, .growing)

        let crop = CropDefinition.crop(id: "radish")!
        // No watering at all — it must still reach ripe.
        save = FarmSimulator.advance(save: save, to: now.addingTimeInterval(crop.growDuration + 60))
        XCTAssertEqual(save.plots[0].phase, .ripe)
    }

    func testNeglectNeverKillsDuringGrowth() {
        var save = SaveGame.fresh(now: Date(timeIntervalSince1970: 2_000_000))
        let now = save.lastSimulatedAt
        save = FarmSimulator.plant(save: save, plotId: 0, seedItemId: "seed_radish", now: now).0
        let crop = CropDefinition.crop(id: "radish")!
        // Far past every old wilt/lost threshold, bone dry the whole time.
        save = FarmSimulator.advance(save: save, to: now.addingTimeInterval(crop.growDuration + 60))
        XCTAssertEqual(save.plots[0].phase, .ripe, "growth must complete regardless of watering")
        XCTAssertNotEqual(save.plots[0].phase, .lost)
    }

    func testUnwateredHarvestYieldsLessThanWatered() {
        let crop = CropDefinition.crop(id: "radish")!

        // Unwatered run.
        var dry = SaveGame.fresh(now: Date(timeIntervalSince1970: 3_000_000))
        let dryNow = dry.lastSimulatedAt
        dry = FarmSimulator.plant(save: dry, plotId: 0, seedItemId: "seed_radish", now: dryNow).0
        dry = FarmSimulator.advance(save: dry, to: dryNow.addingTimeInterval(crop.growDuration + 60))
        let dryBefore = dry.inventoryCount(itemId: "radish")
        dry = FarmSimulator.harvest(save: dry, plotId: 0, now: dryNow.addingTimeInterval(crop.growDuration + 120)).0
        let dryYield = dry.inventoryCount(itemId: "radish") - dryBefore
        XCTAssertLessThan(dryYield, crop.harvestYield, "neglected crop should yield less than full")
        XCTAssertGreaterThanOrEqual(dryYield, 1, "but never nothing")

        // Watered run: keep topping up so the yield meter stays full.
        var wet = SaveGame.fresh(now: Date(timeIntervalSince1970: 4_000_000))
        let wetNow = wet.lastSimulatedAt
        wet = FarmSimulator.plant(save: wet, plotId: 0, seedItemId: "seed_radish", now: wetNow).0
        var t = wetNow
        let step = crop.waterEvery * 0.5
        while t.timeIntervalSince(wetNow) < crop.growDuration {
            t = t.addingTimeInterval(step)
            wet = FarmSimulator.water(save: wet, plotId: 0, now: t).0
        }
        wet = FarmSimulator.advance(save: wet, to: t.addingTimeInterval(60))
        let wetBefore = wet.inventoryCount(itemId: "radish")
        wet = FarmSimulator.harvest(save: wet, plotId: 0, now: t.addingTimeInterval(120)).0
        let wetYield = wet.inventoryCount(itemId: "radish") - wetBefore
        XCTAssertEqual(wetYield, crop.harvestYield, "fully watered crop should give full yield")
        XCTAssertGreaterThan(wetYield, dryYield)
    }

    func testRipeHoldsThenGoesPastPrimeThenComposts() {
        var save = SaveGame.fresh(now: Date(timeIntervalSince1970: 5_000_000))
        let now = save.lastSimulatedAt
        save = FarmSimulator.plant(save: save, plotId: 0, seedItemId: "seed_radish", now: now).0
        let crop = CropDefinition.crop(id: "radish")!

        // Reach ripe.
        var t = now.addingTimeInterval(crop.growDuration + 60)
        save = FarmSimulator.advance(save: save, to: t)
        XCTAssertEqual(save.plots[0].phase, .ripe)

        // Still within the hold window (< overRipeFactor × grow) → stays ripe.
        t = t.addingTimeInterval(crop.growDuration * 1.5)
        save = FarmSimulator.advance(save: save, to: t)
        XCTAssertEqual(save.plots[0].phase, .ripe, "ripe should wait for the player")

        // Past the hold window → past-prime (still harvestable).
        t = t.addingTimeInterval(crop.growDuration)
        save = FarmSimulator.advance(save: save, to: t)
        XCTAssertEqual(save.plots[0].phase, .wilted)

        // Long past that → composts.
        t = t.addingTimeInterval(crop.growDuration * 3)
        save = FarmSimulator.advance(save: save, to: t)
        XCTAssertEqual(save.plots[0].phase, .lost)
    }

    // MARK: - Save safety (Phase 0)

    func testTolerantDecodingSurvivesMissingFields() throws {
        let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601
        let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601

        var original = SaveGame.fresh(now: Date(timeIntervalSince1970: 6_000_000))
        original.coins = 4242
        let data = try enc.encode(original)
        let obj = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        // Simulate an older save that predates these fields — none of these may wipe the farm.
        for key in ["careStreakDays", "settings", "hasCompletedOnboarding", "decorations", "unlockedCropIds"] {
            var trimmed = obj
            trimmed.removeValue(forKey: key)
            let trimmedData = try JSONSerialization.data(withJSONObject: trimmed)
            let decoded = try dec.decode(SaveGame.self, from: trimmedData)
            XCTAssertEqual(decoded.coins, 4242, "decoding without \(key) must not throw or lose data")
        }
    }

    func testAddItemBlendsAcquireTimeSoFreshBatchSurvives() {
        let t0 = Date(timeIntervalSince1970: 7_000_000)
        var save = SaveGame.fresh(now: t0)
        save.lastDailyGrantDayKey = FarmBalance.dayKey(for: t0)

        // A few old radishes, then a big fresh batch 11h later.
        save.addItem("radish", count: 3, at: t0)
        let t11 = t0.addingTimeInterval(11 * 3600)
        save = FarmSimulator.advance(save: save, to: t11)
        save.addItem("radish", count: 30, at: t11)

        // Just past the 12h spoil window for the *oldest* members — fresh ones must remain.
        let t12 = t0.addingTimeInterval(12 * 3600 + 60)
        save = FarmSimulator.advance(save: save, to: t12)
        XCTAssertEqual(save.inventoryCount(itemId: "radish"), 33, "fresh items must not be spoiled away by old stack-mates")
    }

    // MARK: - Chickens (unchanged model)

    func testChickensGetHungryWithoutFeed() {
        var save = SaveGame.fresh(now: Date(timeIntervalSince1970: 8_000_000))
        let now = save.lastSimulatedAt
        let later = now.addingTimeInterval(FarmBalance.feedInterval + 60)
        save = FarmSimulator.advance(save: save, to: later)
        XCTAssertTrue(save.animals.allSatisfy { $0.mood == .hungry || $0.mood == .neglected })
    }

    func testFeedRestoresContent() {
        var save = SaveGame.fresh(now: Date(timeIntervalSince1970: 9_000_000))
        let now = save.lastSimulatedAt
        let later = now.addingTimeInterval(FarmBalance.feedInterval + 60)
        save = FarmSimulator.advance(save: save, to: later)
        save = FarmSimulator.feedAllChickens(save: save, now: later).0
        XCTAssertTrue(save.animals.allSatisfy { $0.mood == .content })
    }

    func testEggsProduceWhileContent() {
        var save = SaveGame.fresh(now: Date(timeIntervalSince1970: 10_000_000))
        let now = save.lastSimulatedAt
        let later = now.addingTimeInterval(FarmBalance.eggInterval + 30)
        save = FarmSimulator.advance(save: save, to: later)
        let eggs = save.animals.reduce(0) { $0 + $1.pendingProduce }
        XCTAssertGreaterThanOrEqual(eggs, 2) // two hens
    }

    // MARK: - Economy safety nets (unchanged model)

    func testDailyStipendGrantsCoinsAndSeeds() {
        var save = SaveGame.fresh(now: Date(timeIntervalSince1970: 11_000_000))
        let day1 = save.lastSimulatedAt
        save.lastDailyGrantDayKey = FarmBalance.dayKey(for: day1)
        let coinsBefore = save.coins
        let seedsBefore = save.inventoryCount(itemId: "seed_radish")

        let day2 = Calendar.current.date(byAdding: .day, value: 1, to: day1)!
        save = FarmSimulator.advance(save: save, to: day2)

        XCTAssertEqual(save.lastDailyGrantDayKey, FarmBalance.dayKey(for: day2))
        XCTAssertEqual(save.coins, coinsBefore + FarmBalance.dailyCoins)
        XCTAssertEqual(save.inventoryCount(itemId: "seed_radish"), seedsBefore + FarmBalance.dailyRadishSeeds)
        XCTAssertNotNil(save.pendingToast)
    }

    func testSoftLockRescueWhenBrokeAndSeedless() {
        var save = SaveGame.fresh(now: Date(timeIntervalSince1970: 12_000_000))
        save.coins = 0
        save.inventory = []
        save.plots = save.plots.map { p in
            var q = p
            q.clearToEmpty()
            return q
        }
        save.lastDailyGrantDayKey = FarmBalance.dayKey(for: save.lastSimulatedAt)

        save = FarmSimulator.advance(save: save, to: save.lastSimulatedAt.addingTimeInterval(2))

        XCTAssertGreaterThanOrEqual(save.coins, FarmBalance.bailoutCoins)
        XCTAssertGreaterThanOrEqual(save.inventoryCount(itemId: "seed_radish"), FarmBalance.bailoutRadishSeeds)
    }
}
