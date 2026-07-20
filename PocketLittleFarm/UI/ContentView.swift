import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: GameStore

    var body: some View {
        ZStack {
            // Bright desk behind SpriteKit (matches scene; helps letterboxing)
            PaperTheme.desk
                .ignoresSafeArea()

            FarmView(store: store)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                Spacer()
                if let toast = store.toast {
                    toastBanner(toast)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 8)
                }
                chickenQuickActions
                toolRail
            }
            .animation(.easeOut(duration: 0.2), value: store.toast)
        }
        .sheet(isPresented: $store.showShop) {
            ShopView()
                .environmentObject(store)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $store.showInventory) {
            InventoryView()
                .environmentObject(store)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $store.showAlmanac) {
            AlmanacView()
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $store.showSettings) {
            SettingsView()
                .environmentObject(store)
                .presentationDetents([.medium])
        }
        .fullScreenCover(isPresented: $store.showOnboarding) {
            OnboardingView()
                .environmentObject(store)
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Pocket Little Farm")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(PaperTheme.ink)
                HStack(spacing: 10) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.yellow.opacity(0.95))
                            .frame(width: 10, height: 10)
                            .overlay(Circle().stroke(PaperTheme.ink.opacity(0.35), lineWidth: 1))
                        Text("\(store.save.coins)")
                            .font(.body.weight(.bold))
                            .foregroundStyle(PaperTheme.ink)
                    }
                    if store.save.needsAttentionCount > 0 {
                        Text("\(store.save.needsAttentionCount) need care")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(PaperTheme.warn)
                    } else {
                        Text("All calm")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(PaperTheme.good)
                    }
                }
            }

            Spacer()

            iconButton("cart.fill") { store.showShop = true }
            iconButton("bag.fill") { store.showInventory = true }
            iconButton("book.fill") { store.showAlmanac = true }
            iconButton("gearshape.fill") { store.showSettings = true }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .paperCard()
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }

    private var chickenQuickActions: some View {
        HStack(spacing: 10) {
            paperActionButton(title: "Feed hens", systemImage: "fork.knife") {
                store.feedChickens()
            }
            let eggs = store.save.animals.reduce(0) { $0 + $1.pendingProduce }
            paperActionButton(
                title: eggs > 0 ? "Eggs (\(eggs))" : "Eggs",
                systemImage: "oval.portrait.fill"
            ) {
                store.collectEggs()
            }

            if let seed = store.save.selectedSeedItemId,
               let def = ItemDefinition.item(id: seed) {
                Text(def.displayName)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(PaperTheme.ink)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(PaperTheme.stage)
                    .overlay(
                        Capsule().strokeBorder(PaperTheme.good.opacity(0.55), lineWidth: 2)
                    )
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    private var toolRail: some View {
        HStack(spacing: 6) {
            ForEach(FarmTool.allCases) { tool in
                Button {
                    store.selectedTool = tool
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tool.systemImage)
                            .font(.system(size: 20, weight: .bold))
                        Text(tool.title)
                            .font(.caption.weight(.bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundStyle(store.selectedTool == tool ? Color.white : PaperTheme.ink)
                    .background(
                        store.selectedTool == tool
                            ? PaperTheme.accent
                            : Color.clear,
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .paperCard(cornerRadius: 20)
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
    }

    private func paperActionButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(PaperTheme.ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(PaperTheme.stage)
                .overlay(Capsule().strokeBorder(PaperTheme.stageEdge.opacity(0.6), lineWidth: 1.5))
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
    }

    private func iconButton(_ systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(PaperTheme.ink)
                .frame(width: 40, height: 40)
                .background(Color.white.opacity(0.85), in: Circle())
                .overlay(Circle().strokeBorder(PaperTheme.stageEdge.opacity(0.5), lineWidth: 1.2))
        }
        .buttonStyle(.plain)
    }

    private func toastBanner(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.bold))
            .foregroundStyle(PaperTheme.ink)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(PaperTheme.stage)
            .overlay(Capsule().strokeBorder(PaperTheme.stageEdge.opacity(0.55), lineWidth: 1.5))
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
            .padding(.horizontal, 24)
    }
}

#Preview {
    ContentView()
        .environmentObject(GameStore())
}
