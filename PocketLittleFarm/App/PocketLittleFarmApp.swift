import SwiftUI

@main
struct PocketLittleFarmApp: App {
    @StateObject private var store = GameStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                store.scenePhaseChanged(.active)
            case .inactive:
                store.scenePhaseChanged(.inactive)
            case .background:
                store.scenePhaseChanged(.background)
            @unknown default:
                break
            }
        }
    }
}
