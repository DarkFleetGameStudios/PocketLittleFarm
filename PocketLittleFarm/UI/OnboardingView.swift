import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var store: GameStore

    var body: some View {
        ZStack {
            // Bright paper desk
            PaperTheme.desk
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                // Paper stage sample
                VStack(spacing: 12) {
                    Text("🪴")
                        .font(.system(size: 64))
                    Text("Pocket Little Farm")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(PaperTheme.ink)
                    Text("A little paper farm on your phone.\nCheck in for a minute or two — water, harvest, feed — then go live your day.")
                        .font(.body.weight(.medium))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(PaperTheme.inkMuted)
                        .padding(.horizontal, 8)
                }
                .padding(28)
                .frame(maxWidth: 360)
                .paperCard(cornerRadius: 24)

                VStack(alignment: .leading, spacing: 16) {
                    tip(icon: "drop.fill", title: "Care matters", text: "Miss watering and crops get thirsty, then wilt. Soft stakes — not a chore app.")
                    tip(icon: "clock.fill", title: "Short sessions", text: "Peek, tend, close. Nothing needs a long grind.")
                    tip(icon: "wifi.slash", title: "Fully offline", text: "No account. No servers. Your farm saves on device.")
                }
                .padding(20)
                .frame(maxWidth: 360)
                .paperCard(cornerRadius: 20)

                Spacer()

                Button {
                    store.completeOnboarding()
                } label: {
                    Text("Open my farm")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(PaperTheme.accent, in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 28)
                .padding(.bottom, 36)
                .frame(maxWidth: 400)
            }
            .padding(.horizontal, 20)
        }
    }

    private func tip(icon: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3.weight(.bold))
                .foregroundStyle(PaperTheme.accent)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(PaperTheme.ink)
                Text(text)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(PaperTheme.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
