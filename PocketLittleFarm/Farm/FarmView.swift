import SwiftUI
import SpriteKit

struct FarmView: UIViewRepresentable {
    @ObservedObject var store: GameStore

    func makeCoordinator() -> Coordinator {
        Coordinator(store: store)
    }

    func makeUIView(context: Context) -> SKView {
        let view = SKView(frame: .zero)
        view.ignoresSiblingOrder = true
        #if DEBUG
        view.showsFPS = false
        view.showsNodeCount = false
        #endif

        let scene = FarmScene(size: UIScreen.main.bounds.size)
        scene.scaleMode = .resizeFill
        scene.farmDelegate = context.coordinator
        context.coordinator.scene = scene
        view.presentScene(scene)
        scene.apply(save: store.save)
        context.coordinator.lastRenderToken = store.renderToken
        return view
    }

    func updateUIView(_ uiView: SKView, context: Context) {
        context.coordinator.store = store
        if let scene = context.coordinator.scene {
            if scene.size != uiView.bounds.size, uiView.bounds.size.width > 0 {
                scene.size = uiView.bounds.size
            }
            if context.coordinator.lastRenderToken != store.renderToken {
                context.coordinator.lastRenderToken = store.renderToken
                scene.apply(save: store.save)
            }
        }
    }

    final class Coordinator: NSObject, FarmSceneDelegate {
        var store: GameStore
        weak var scene: FarmScene?
        var lastRenderToken: Int = -1

        init(store: GameStore) {
            self.store = store
        }

        func farmScene(_ scene: FarmScene, didTapPlotId id: Int) {
            Task { @MainActor in
                store.tapPlot(id: id)
            }
        }

        func farmSceneDidTapChickenPen(_ scene: FarmScene) {
            Task { @MainActor in
                // Prefer collect if eggs, else feed
                let eggs = store.save.animals.reduce(0) { $0 + $1.pendingProduce }
                if eggs > 0 {
                    store.collectEggs()
                } else {
                    store.feedChickens()
                }
            }
        }
    }
}
