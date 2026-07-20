import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: GameStore
    @Environment(\.dismiss) private var dismiss
    @State private var confirmReset = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Farm") {
                    LabeledContent("Care streak") {
                        Text("\(store.save.careStreakDays) day\(store.save.careStreakDays == 1 ? "" : "s")")
                    }
                    LabeledContent("Plots") {
                        Text("\(SaveGame.gridCols)×\(SaveGame.gridRows)")
                    }
                    LabeledContent("Mode") {
                        Text("Offline")
                    }
                }

                Section("Debug time skip") {
                    Text("Advance farm simulation without waiting. Great for testing wilt and eggs.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Skip 30 minutes") { store.debugSkip(seconds: 30 * 60) }
                    Button("Skip 2 hours") { store.debugSkip(seconds: 2 * 60 * 60) }
                    Button("Skip 8 hours") { store.debugSkip(seconds: 8 * 60 * 60) }
                    Button("Skip 1 day") { store.debugSkip(seconds: 24 * 60 * 60) }
                }

                Section {
                    Button("Reset farm…", role: .destructive) {
                        confirmReset = true
                    }
                }

                Section("About") {
                    Text("A cozy offline farm for short check-ins. No account, no ads, no energy bars.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    LabeledContent("Version", value: "0.1.0")
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog("Reset farm?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Reset everything", role: .destructive) {
                    store.resetFarm()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This erases your local save. You can't undo it.")
            }
        }
    }
}
