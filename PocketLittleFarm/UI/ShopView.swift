import SwiftUI

struct ShopView: View {
    @EnvironmentObject private var store: GameStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Seeds") {
                    ForEach(CropDefinition.all) { crop in
                        shopRow(
                            title: "\(crop.displayName) Seeds",
                            subtitle: "Grows in \(formatDuration(crop.growDuration)) · water ~\(formatDuration(crop.waterEvery))",
                            price: crop.seedPrice,
                            itemId: crop.seedItemId,
                            owned: store.save.inventoryCount(itemId: crop.seedItemId)
                        ) {
                            store.selectSeed(crop.seedItemId)
                        }
                    }
                }

                Section("Supplies") {
                    let feed = ItemDefinition.feed
                    shopRow(
                        title: feed.displayName,
                        subtitle: "Feeds the whole pen",
                        price: feed.buyPrice ?? 0,
                        itemId: feed.id,
                        owned: store.save.inventoryCount(itemId: feed.id)
                    )
                }

                Section("Decorations") {
                    ForEach(DecorationDefinition.all) { deco in
                        shopRow(
                            title: deco.displayName,
                            subtitle: "Make the farm yours",
                            price: deco.price,
                            itemId: deco.id,
                            owned: store.save.inventoryCount(itemId: deco.id)
                        )
                    }
                }
            }
            .navigationTitle("Farm Shop")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text("\(store.save.coins) coins")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func shopRow(
        title: String,
        subtitle: String,
        price: Int,
        itemId: String,
        owned: Int,
        onSelectSeed: (() -> Void)? = nil
    ) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.body.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if owned > 0 {
                    Text("Owned: \(owned)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(spacing: 6) {
                Button {
                    store.buy(itemId: itemId)
                } label: {
                    Text("\(price)¢")
                        .font(.subheadline.weight(.bold))
                        .frame(minWidth: 56)
                }
                .buttonStyle(.borderedProminent)
                .disabled(store.save.coins < price)

                if let onSelectSeed {
                    Button("Use", action: onSelectSeed)
                        .font(.caption.weight(.semibold))
                        .disabled(owned == 0 && store.save.inventoryCount(itemId: itemId) == 0)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func formatDuration(_ t: TimeInterval) -> String {
        if t < 3600 { return "\(Int(t / 60))m" }
        if t < 86400 {
            let h = t / 3600
            return h == floor(h) ? "\(Int(h))h" : String(format: "%.1fh", h)
        }
        return "\(Int(t / 86400))d"
    }
}
