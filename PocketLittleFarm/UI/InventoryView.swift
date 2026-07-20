import SwiftUI

struct InventoryView: View {
    @EnvironmentObject private var store: GameStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if store.save.inventory.isEmpty {
                    ContentUnavailableView(
                        "Empty baskets",
                        systemImage: "basket",
                        description: Text("Harvest crops or collect eggs to fill your inventory.")
                    )
                } else {
                    Section {
                        ForEach(store.save.inventory, id: \.itemId) { stack in
                            let def = ItemDefinition.item(id: stack.itemId)
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(def?.displayName ?? stack.itemId)
                                        .font(.body.weight(.semibold))
                                    Text(kindLabel(def?.kind))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("×\(stack.count)")
                                    .font(.title3.monospacedDigit().weight(.bold))
                                if let def, def.sellPrice > 0, def.kind == .harvest || def.kind == .animalProduct {
                                    Button("Sell") {
                                        store.sell(itemId: stack.itemId, quantity: stack.count)
                                    }
                                    .buttonStyle(.bordered)
                                }
                                if def?.kind == .seed {
                                    Button("Plant") {
                                        store.selectSeed(stack.itemId)
                                        dismiss()
                                    }
                                    .buttonStyle(.borderedProminent)
                                }
                            }
                        }
                    }

                    Section {
                        Button {
                            store.sellAllGoods()
                        } label: {
                            Label("Sell all crops & eggs", systemImage: "coloncurrencysign.circle")
                        }
                    }
                }
            }
            .navigationTitle("Inventory")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func kindLabel(_ kind: ItemKind?) -> String {
        switch kind {
        case .seed: return "Seeds"
        case .harvest: return "Harvest"
        case .animalProduct: return "Animal product"
        case .feed: return "Feed"
        case .decoration: return "Decoration"
        case .none: return "Item"
        }
    }
}
