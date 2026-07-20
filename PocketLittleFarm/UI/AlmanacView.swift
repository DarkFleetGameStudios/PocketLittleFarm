import SwiftUI

struct AlmanacView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("How care works") {
                    Text("Your farm keeps living while the app is closed. Growth uses real time. Miss watering long enough and crops get thirsty, then wilt, then may be lost. Animals need feed or they stop laying.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Sessions are meant to be short: peek, water, harvest, feed, close. Come back later.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Section("Morning post") {
                    Text("Each calendar day you open the farm you get a small delivery: coins, radish seeds, and feed. If you ever go totally broke with no seeds and nothing growing, a farmers' fund pack kicks in. Dead plants compost for a couple coins and a seed.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Section("Crops") {
                    ForEach(CropDefinition.all) { crop in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(crop.displayName)
                                .font(.headline)
                            grid(
                                ("Grow", format(crop.growDuration)),
                                ("Water every", format(crop.waterEvery)),
                                ("Thirst grace", format(crop.thirstGrace)),
                                ("Wilt → lost", format(crop.wiltToLost)),
                                ("Seed", "\(crop.seedPrice)¢"),
                                ("Sell", "\(crop.sellPrice)¢ each")
                            )
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("Chickens") {
                    grid(
                        ("Feed window", format(FarmBalance.feedInterval)),
                        ("Then hungry", format(FarmBalance.hungryGrace) + " grace"),
                        ("Egg every", format(FarmBalance.eggInterval) + " (if content)"),
                        ("Max waiting eggs", "\(FarmBalance.maxPendingEggsPerHen) / hen")
                    )
                }
            }
            .navigationTitle("Almanac")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func grid(_ pairs: (String, String)...) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(pairs.enumerated()), id: \.offset) { _, pair in
                HStack {
                    Text(pair.0)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(pair.1)
                        .font(.caption.weight(.semibold))
                }
            }
        }
    }

    private func format(_ t: TimeInterval) -> String {
        if t < 3600 { return "\(Int(t / 60)) min" }
        let h = t / 3600
        if h < 24 {
            return h == floor(h) ? "\(Int(h)) h" : String(format: "%.1f h", h)
        }
        return "\(Int(t / 86400)) d"
    }
}
