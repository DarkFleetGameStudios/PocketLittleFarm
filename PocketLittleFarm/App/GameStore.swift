import Foundation
import Combine
import UIKit

enum FarmTool: String, CaseIterable, Identifiable {
    case plant
    case water
    case harvest
    case info

    var id: String { rawValue }

    var title: String {
        switch self {
        case .plant: return "Plant"
        case .water: return "Water"
        case .harvest: return "Harvest"
        case .info: return "Look"
        }
    }

    var systemImage: String {
        switch self {
        case .plant: return "leaf.fill"
        case .water: return "drop.fill"
        case .harvest: return "basket.fill"
        case .info: return "eye.fill"
        }
    }
}

@MainActor
final class GameStore: ObservableObject {
    @Published private(set) var save: SaveGame
    @Published var selectedTool: FarmTool = .plant
    @Published var toast: String?
    @Published var showShop = false
    @Published var showInventory = false
    @Published var showAlmanac = false
    @Published var showSettings = false
    @Published var showOnboarding: Bool

    /// Bumped so SpriteKit scene reloads visuals.
    @Published private(set) var renderToken: Int = 0

    private var toastTask: Task<Void, Never>?
    private var saveTask: Task<Void, Never>?

    init() {
        let loaded = SaveStore.load()
        self.save = loaded
        self.showOnboarding = !loaded.hasCompletedOnboarding
        // Morning post / bailout may have been applied during load.
        if let message = loaded.pendingToast, !message.isEmpty {
            // Defer toast slightly so UI is up
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 400_000_000)
                self.presentToast(message)
                self.save.pendingToast = nil
                self.persist()
            }
        }
    }

    // MARK: - Lifecycle

    func scenePhaseChanged(_ phase: ScenePhaseCompat) {
        switch phase {
        case .active:
            resimulate()
        case .inactive, .background:
            persist()
        }
    }

    func resimulate() {
        save = FarmSimulator.advance(save: save, to: Date())
        consumePendingToast()
        bumpRender()
        persist()
    }

    private func consumePendingToast() {
        if let message = save.pendingToast, !message.isEmpty {
            presentToast(message)
            save.pendingToast = nil
        }
    }

    func persist() {
        do {
            try SaveStore.save(save)
        } catch {
            presentToast("Couldn't save farm.")
        }
    }

    // MARK: - Actions

    func tapPlot(id: Int) {
        let now = Date()
        switch selectedTool {
        case .plant:
            let seed = save.selectedSeedItemId ?? "seed_radish"
            apply(FarmSimulator.plant(save: save, plotId: id, seedItemId: seed, now: now))
        case .water:
            apply(FarmSimulator.water(save: save, plotId: id, now: now))
        case .harvest:
            apply(FarmSimulator.harvest(save: save, plotId: id, now: now))
        case .info:
            presentPlotInfo(id: id)
        }
    }

    func selectSeed(_ seedItemId: String) {
        save.selectedSeedItemId = seedItemId
        selectedTool = .plant
        persist()
    }

    func feedChickens() {
        apply(FarmSimulator.feedAllChickens(save: save, now: Date()))
    }

    func collectEggs() {
        apply(FarmSimulator.collectEggs(save: save, now: Date()))
    }

    func buy(itemId: String, quantity: Int = 1) {
        apply(FarmSimulator.buy(save: save, itemId: itemId, quantity: quantity, now: Date()))
    }

    func sell(itemId: String, quantity: Int = 1) {
        apply(FarmSimulator.sell(save: save, itemId: itemId, quantity: quantity, now: Date()))
    }

    func sellAllGoods() {
        apply(FarmSimulator.sellAllHarvest(save: save, now: Date()))
    }

    func completeOnboarding() {
        save.hasCompletedOnboarding = true
        showOnboarding = false
        persist()
    }

    func resetFarm() {
        SaveStore.delete()
        save = .fresh()
        showOnboarding = true
        bumpRender()
        persist()
        presentToast("Fresh farm ready.")
    }

    /// Debug / balance: skip real-world time.
    func debugSkip(seconds: TimeInterval) {
        let fakeNow = save.lastSimulatedAt.addingTimeInterval(seconds)
        save = FarmSimulator.advance(save: save, to: fakeNow)
        // Keep wall clock consistent for next real open: set lastSimulatedAt to real now
        // after applying delta from a virtual point. Better approach: advance by delta using now.
        // Re-do properly:
        let now = Date()
        // We want to simulate `seconds` of farm time. Temporarily backdate lastSimulatedAt.
        var snap = save
        // save already advanced to fakeNow; set lastSimulatedAt to now so future real time is correct
        // but state already includes the skip. Good.
        snap.lastSimulatedAt = now
        save = snap
        bumpRender()
        persist()
        presentToast(debugSkipLabel(seconds))
    }

    // MARK: - Private

    private func apply(_ result: (SaveGame, String?)) {
        save = result.0
        if let message = result.1 {
            presentToast(message)
        } else {
            consumePendingToast()
        }
        save.pendingToast = nil
        bumpRender()
        persist()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func presentPlotInfo(id: Int) {
        guard let plot = save.plots.first(where: { $0.id == id }) else { return }
        switch plot.phase {
        case .empty:
            presentToast("Empty soil. Plant something!")
        case .growing:
            if let crop = plot.cropId.flatMap(CropDefinition.crop(id:)) {
                let pct = Int((plot.growProgress / crop.growDuration) * 100)
                presentToast("\(crop.displayName) growing — \(pct)%. Water for a fuller harvest.")
            }
        case .thirsty:
            presentToast("Dry — water for the best harvest. It won't die.")
        case .wilted:
            presentToast("Past-prime — still good to harvest, just a smaller pick.")
        case .ripe:
            presentToast("Ripe! Harvest whenever — it'll wait for you.")
        case .lost:
            presentToast("Composted over. Harvest/clear to free the plot.")
        }
    }

    private func presentToast(_ message: String) {
        toastTask?.cancel()
        toast = message
        toastTask = Task {
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            if !Task.isCancelled {
                toast = nil
            }
        }
    }

    private func bumpRender() {
        renderToken &+= 1
    }

    private func debugSkipLabel(_ seconds: TimeInterval) -> String {
        if seconds < 3600 { return "Skipped \(Int(seconds / 60)) min." }
        if seconds < 86400 { return "Skipped \(Int(seconds / 3600)) h." }
        return "Skipped \(Int(seconds / 86400)) day(s)."
    }
}

/// Avoid importing SwiftUI in model layer; map from ContentView.
enum ScenePhaseCompat {
    case active, inactive, background
}
