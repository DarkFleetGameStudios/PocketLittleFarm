import Foundation

/// Pure offline simulation: advance living systems by wall-clock delta.
enum FarmSimulator {

    // MARK: - Time advance

    static func advance(save: SaveGame, to now: Date) -> SaveGame {
        var state = save
        var delta = now.timeIntervalSince(state.lastSimulatedAt)
        if delta < 0 {
            // Clock moved backward — snap without rewinding care (fair offline single-player).
            state.lastSimulatedAt = now
            applyDailyStipend(&state, now: now)
            applySoftLockRescue(&state, now: now)
            return state
        }
        delta = min(delta, FarmBalance.maxSimDelta)
        if delta > 0.5 {
            state.plots = state.plots.map { advancePlot($0, delta: delta) }
            state.animals = state.animals.map { advanceAnimal($0, delta: delta) }
            state.inventory = spoilInventory(state.inventory, now: now)
        }
        state.lastSimulatedAt = now
        applyDailyStipend(&state, now: now)
        applySoftLockRescue(&state, now: now)
        return state
    }

    /// Once per calendar day: coins + a few seeds + feed so neglect never hard-locks you.
    private static func applyDailyStipend(_ state: inout SaveGame, now: Date) {
        let today = FarmBalance.dayKey(for: now)
        if state.lastDailyGrantDayKey == today { return }

        var days = 1
        if let lastKey = state.lastDailyGrantDayKey,
           let lastDate = FarmBalance.dayKeyFormatter.date(from: lastKey) {
            let raw = Calendar.current.dateComponents([.day], from: lastDate, to: Calendar.current.startOfDay(for: now)).day ?? 1
            days = min(FarmBalance.maxDailyCatchUpDays, max(1, raw))
        }

        let coins = FarmBalance.dailyCoins * days
        let seeds = FarmBalance.dailyRadishSeeds * days
        let feed = FarmBalance.dailyFeed * days
        state.coins += coins
        state.addItem("seed_radish", count: seeds, at: now)
        state.addItem(ItemDefinition.feed.id, count: feed, at: now)
        state.lastDailyGrantDayKey = today
        state.selectedSeedItemId = state.selectedSeedItemId ?? "seed_radish"

        if days == 1 {
            state.pendingToast = "Morning post: +\(coins) coins, \(seeds) radish seeds, \(feed) feed"
        } else {
            state.pendingToast = "Mail caught up (\(days) days): +\(coins) coins & supplies"
        }
    }

    /// Broke + no seeds + nothing alive → farmers' fund starter pack.
    private static func applySoftLockRescue(_ state: inout SaveGame, now: Date) {
        guard state.totalSeedCount == 0 else { return }
        guard !state.hasLivingCrops else { return }
        guard state.coins < state.cheapestSeedPrice else { return }

        state.coins += FarmBalance.bailoutCoins
        state.addItem("seed_radish", count: FarmBalance.bailoutRadishSeeds, at: now)
        state.addItem(ItemDefinition.feed.id, count: FarmBalance.bailoutFeed, at: now)
        state.selectedSeedItemId = "seed_radish"
        state.pendingToast = "Farmers' fund: +\(FarmBalance.bailoutCoins) coins & starter seeds — you're back in business"
    }

    private static func advancePlot(_ plot: PlotState, delta: TimeInterval) -> PlotState {
        var p = plot
        guard let cropId = p.cropId, let crop = CropDefinition.crop(id: cropId) else {
            return p
        }

        var remaining = delta
        // Step in small chunks so water/wilt thresholds are respected without full event queue.
        // For mobile offline, single-pass piecewise is enough.
        switch p.phase {
        case .empty, .lost:
            return p
        case .ripe:
            return p
        case .growing:
            applyGrowing(&p, crop: crop, delta: &remaining)
        case .thirsty:
            applyThirsty(&p, crop: crop, delta: &remaining)
        case .wilted:
            applyWilted(&p, crop: crop, delta: &remaining)
        }
        return p
    }

    private static func applyGrowing(_ p: inout PlotState, crop: CropDefinition, delta: inout TimeInterval) {
        // Split: time until thirsty vs grow progress
        let untilThirsty = max(0, crop.waterEvery - p.sinceWatered)
        if delta <= untilThirsty {
            p.sinceWatered += delta
            p.growProgress += delta
            delta = 0
            if p.growProgress >= crop.growDuration {
                p.phase = .ripe
                p.growProgress = crop.growDuration
            }
            return
        }

        // Grow until thirsty threshold
        p.growProgress += untilThirsty
        p.sinceWatered = crop.waterEvery
        delta -= untilThirsty
        if p.growProgress >= crop.growDuration {
            p.phase = .ripe
            p.growProgress = crop.growDuration
            delta = 0
            return
        }
        p.phase = .thirsty
        p.thirstyAccumulated = 0
        applyThirsty(&p, crop: crop, delta: &delta)
    }

    private static func applyThirsty(_ p: inout PlotState, crop: CropDefinition, delta: inout TimeInterval) {
        // Growth paused while thirsty
        let untilWilt = max(0, crop.thirstGrace - p.thirstyAccumulated)
        if delta <= untilWilt {
            p.thirstyAccumulated += delta
            delta = 0
            return
        }
        p.thirstyAccumulated = crop.thirstGrace
        delta -= untilWilt
        p.phase = .wilted
        p.wiltedAccumulated = 0
        applyWilted(&p, crop: crop, delta: &delta)
    }

    private static func applyWilted(_ p: inout PlotState, crop: CropDefinition, delta: inout TimeInterval) {
        let untilLost = max(0, crop.wiltToLost - p.wiltedAccumulated)
        if delta <= untilLost {
            p.wiltedAccumulated += delta
            delta = 0
            return
        }
        p.wiltedAccumulated = crop.wiltToLost
        delta = 0
        p.phase = .lost
    }

    private static func advanceAnimal(_ animal: AnimalState, delta: TimeInterval) -> AnimalState {
        var a = animal
        a.sinceFed += delta

        let hungryAt = FarmBalance.feedInterval
        let neglectedAt = FarmBalance.feedInterval + FarmBalance.hungryGrace

        if a.sinceFed >= neglectedAt {
            a.mood = .neglected
        } else if a.sinceFed >= hungryAt {
            a.mood = .hungry
        } else {
            a.mood = .content
        }

        // Produce only while content
        if a.mood == .content {
            a.produceProgress += delta
            while a.produceProgress >= FarmBalance.eggInterval && a.pendingProduce < FarmBalance.maxPendingEggsPerHen {
                a.produceProgress -= FarmBalance.eggInterval
                a.pendingProduce += 1
            }
            if a.pendingProduce >= FarmBalance.maxPendingEggsPerHen {
                a.produceProgress = min(a.produceProgress, FarmBalance.eggInterval)
            }
        }
        // Hungry/neglected: production paused (progress frozen)

        return a
    }

    private static func spoilInventory(_ inventory: [InventoryStack], now: Date) -> [InventoryStack] {
        inventory.compactMap { stack in
            guard let def = ItemDefinition.item(id: stack.itemId), def.spoilAfter > 0 else {
                return stack
            }
            let age = now.timeIntervalSince(stack.acquiredAt)
            if age >= def.spoilAfter {
                return nil // spoiled away
            }
            return stack
        }
    }

    // MARK: - Player actions

    static func plant(save: SaveGame, plotId: Int, seedItemId: String, now: Date) -> (SaveGame, String?) {
        var state = advance(save: save, to: now)
        guard let crop = CropDefinition.crop(forSeedItemId: seedItemId) else {
            return (state, "Unknown seeds.")
        }
        guard let idx = state.plots.firstIndex(where: { $0.id == plotId }) else {
            return (state, "Plot not found.")
        }
        let phase = state.plots[idx].phase
        guard phase == .empty || phase == .lost else {
            return (state, "That plot is busy.")
        }
        guard state.removeItem(seedItemId, count: 1) else {
            return (state, "No \(crop.displayName) seeds.")
        }

        var plot = state.plots[idx]
        plot.phase = .growing
        plot.cropId = crop.id
        plot.growProgress = 0
        plot.thirstyAccumulated = 0
        plot.wiltedAccumulated = 0
        plot.sinceWatered = 0
        plot.plantedAt = now
        plot.lastWateredAt = now
        state.plots[idx] = plot
        state = noteCare(state, at: now)
        return (state, nil)
    }

    static func water(save: SaveGame, plotId: Int, now: Date) -> (SaveGame, String?) {
        var state = advance(save: save, to: now)
        guard let idx = state.plots.firstIndex(where: { $0.id == plotId }) else {
            return (state, "Plot not found.")
        }
        var plot = state.plots[idx]
        guard let cropId = plot.cropId, CropDefinition.crop(id: cropId) != nil else {
            return (state, "Nothing to water.")
        }

        switch plot.phase {
        case .growing:
            plot.sinceWatered = 0
            plot.lastWateredAt = now
        case .thirsty:
            plot.phase = .growing
            plot.sinceWatered = 0
            plot.thirstyAccumulated = 0
            plot.lastWateredAt = now
        case .wilted:
            // Revive once: back to growing, keep partial progress, clear wilt counters
            plot.phase = .growing
            plot.sinceWatered = 0
            plot.thirstyAccumulated = 0
            plot.wiltedAccumulated = 0
            plot.lastWateredAt = now
        case .ripe:
            return (state, "Already ripe — harvest instead.")
        case .empty, .lost:
            return (state, "Nothing to water.")
        }

        state.plots[idx] = plot
        state = noteCare(state, at: now)
        return (state, nil)
    }

    static func harvest(save: SaveGame, plotId: Int, now: Date) -> (SaveGame, String?) {
        var state = advance(save: save, to: now)
        guard let idx = state.plots.firstIndex(where: { $0.id == plotId }) else {
            return (state, "Plot not found.")
        }
        var plot = state.plots[idx]
        guard plot.phase == .ripe || plot.phase == .wilted,
              let cropId = plot.cropId,
              let crop = CropDefinition.crop(id: cropId) else {
            if plot.phase == .lost {
                plot.clearToEmpty()
                state.plots[idx] = plot
                state.coins += FarmBalance.compostCoins
                state.addItem("seed_radish", count: 1, at: now)
                return (state, "Composted — +\(FarmBalance.compostCoins) coins & 1 seed.")
            }
            return (state, "Not ready to harvest.")
        }

        let factor = plot.phase == .wilted ? crop.wiltedYieldFactor : 1.0
        let amount = max(1, Int((Double(crop.harvestYield) * factor).rounded()))
        state.addItem(crop.harvestItemId, count: amount, at: now)
        plot.clearToEmpty()
        state.plots[idx] = plot
        state = noteCare(state, at: now)
        return (state, "Harvested \(amount)× \(crop.displayName).")
    }

    static func clearLost(save: SaveGame, plotId: Int, now: Date) -> (SaveGame, String?) {
        var state = advance(save: save, to: now)
        guard let idx = state.plots.firstIndex(where: { $0.id == plotId }) else {
            return (state, "Plot not found.")
        }
        guard state.plots[idx].phase == .lost else {
            return (state, "Plot is fine.")
        }
        state.plots[idx].clearToEmpty()
        state.coins += FarmBalance.compostCoins
        state.addItem("seed_radish", count: 1, at: now)
        return (state, "Composted — +\(FarmBalance.compostCoins) coins & 1 seed.")
    }

    static func feedAllChickens(save: SaveGame, now: Date) -> (SaveGame, String?) {
        var state = advance(save: save, to: now)
        let hungryCount = state.animals.filter { $0.kind == "chicken" }.count
        guard hungryCount > 0 else { return (state, "No chickens.") }
        // One feed item feeds the whole pen
        guard state.removeItem(ItemDefinition.feed.id, count: 1) else {
            return (state, "Need chicken feed.")
        }
        for i in state.animals.indices where state.animals[i].kind == "chicken" {
            state.animals[i].sinceFed = 0
            state.animals[i].mood = .content
        }
        state = noteCare(state, at: now)
        return (state, "Chickens fed. Happy clucks!")
    }

    static func collectEggs(save: SaveGame, now: Date) -> (SaveGame, String?) {
        var state = advance(save: save, to: now)
        var total = 0
        for i in state.animals.indices {
            total += state.animals[i].pendingProduce
            state.animals[i].pendingProduce = 0
        }
        guard total > 0 else { return (state, "No eggs waiting.") }
        state.addItem(ItemDefinition.egg.id, count: total, at: now)
        state = noteCare(state, at: now)
        return (state, "Collected \(total) egg\(total == 1 ? "" : "s").")
    }

    static func buy(save: SaveGame, itemId: String, quantity: Int, now: Date) -> (SaveGame, String?) {
        var state = advance(save: save, to: now)
        guard quantity > 0, let def = ItemDefinition.item(id: itemId), let price = def.buyPrice else {
            return (state, "Can't buy that.")
        }
        let cost = price * quantity
        guard state.coins >= cost else { return (state, "Not enough coins.") }
        state.coins -= cost
        state.addItem(itemId, count: quantity, at: now)
        return (state, "Bought \(quantity)× \(def.displayName).")
    }

    static func sell(save: SaveGame, itemId: String, quantity: Int, now: Date) -> (SaveGame, String?) {
        var state = advance(save: save, to: now)
        guard quantity > 0, let def = ItemDefinition.item(id: itemId) else {
            return (state, "Can't sell that.")
        }
        guard def.kind != .seed || true else { return (state, "Can't sell that.") }
        guard state.removeItem(itemId, count: quantity) else {
            return (state, "Not enough items.")
        }
        state.coins += def.sellPrice * quantity
        return (state, "Sold \(quantity)× \(def.displayName) for \(def.sellPrice * quantity) coins.")
    }

    static func sellAllHarvest(save: SaveGame, now: Date) -> (SaveGame, String?) {
        var state = advance(save: save, to: now)
        var earned = 0
        let sellable = state.inventory.filter { stack in
            guard let def = ItemDefinition.item(id: stack.itemId) else { return false }
            return def.kind == .harvest || def.kind == .animalProduct
        }
        guard !sellable.isEmpty else { return (state, "Nothing to sell.") }
        for stack in sellable {
            guard let def = ItemDefinition.item(id: stack.itemId) else { continue }
            earned += def.sellPrice * stack.count
            state.removeItem(stack.itemId, count: stack.count)
        }
        state.coins += earned
        return (state, "Sold goods for \(earned) coins.")
    }

    static func placeDecoration(save: SaveGame, decorationId: String, row: Int, col: Int, now: Date) -> (SaveGame, String?) {
        var state = advance(save: save, to: now)
        guard DecorationDefinition.byId[decorationId] != nil else {
            return (state, "Unknown decoration.")
        }
        // Decor sits on non-plot border conceptually; allow on empty plots only for v1 simplicity
        guard state.removeItem(decorationId, count: 1) else {
            return (state, "You don't have that decoration.")
        }
        let placed = PlacedDecoration(
            id: UUID().uuidString,
            decorationId: decorationId,
            row: row,
            col: col
        )
        state.decorations.append(placed)
        return (state, "Placed decoration.")
    }

    private static func noteCare(_ save: SaveGame, at now: Date) -> SaveGame {
        var state = save
        let key = FarmBalance.dayKey(for: now)
        if state.lastCareDayKey != key {
            if let last = state.lastCareDayKey,
               let lastDate = FarmBalance.dayKeyFormatter.date(from: last),
               let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now),
               FarmBalance.dayKey(for: yesterday) == last {
                state.careStreakDays += 1
            } else if state.lastCareDayKey == nil {
                state.careStreakDays = 1
            } else {
                state.careStreakDays = 1
            }
            state.lastCareDayKey = key
        }
        return state
    }
}
