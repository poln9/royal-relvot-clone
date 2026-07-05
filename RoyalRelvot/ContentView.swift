import SwiftUI
import SpriteKit

struct ContentView: View {
    @StateObject private var viewModel = GameViewModel()

    var body: some View {
        ZStack {
            if viewModel.screen == .menu {
                MenuView(viewModel: viewModel)
            } else {
                gameLayer
            }
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.screen)
    }

    @ViewBuilder
    private var gameLayer: some View {
        ZStack {
            if let scene = viewModel.scene {
                SpriteView(scene: scene, options: [.ignoresSiblingOrder])
                    .ignoresSafeArea()
            }
            if viewModel.screen == .playing {
                HUDOverlay(viewModel: viewModel)
            }
            if viewModel.screen == .victory || viewModel.screen == .defeat {
                ResultOverlay(viewModel: viewModel)
            }
        }
    }
}

// MARK: - Menu principale

struct MenuView: View {
    @ObservedObject var viewModel: GameViewModel

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.10, green: 0.16, blue: 0.32),
                                    Color(red: 0.05, green: 0.07, blue: 0.15)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()
                Text("👑")
                    .font(.system(size: 84))
                Text("Royal Relvot")
                    .font(.system(size: 44, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(colors: [.yellow, .orange],
                                       startPoint: .top, endPoint: .bottom))
                Text("Guida il Re fino al portone nemico!")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.8))

                VStack(spacing: 14) {
                    ForEach(1...viewModel.levelCount, id: \.self) { index in
                        LevelButton(index: index,
                                    name: LevelDefinition.all[index - 1].name,
                                    locked: index > viewModel.unlockedLevel) {
                            viewModel.startLevel(index)
                        }
                    }
                }
                .padding(.top, 12)

                Spacer()
                Text("Tocca il terreno per muovere il Re · Clone didattico")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.45))
                    .padding(.bottom, 10)
            }
            .padding(.horizontal, 32)
        }
    }
}

struct LevelButton: View {
    let index: Int
    let name: String
    let locked: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(locked ? "🔒" : "⚔️")
                VStack(alignment: .leading, spacing: 2) {
                    Text("Livello \(index)")
                        .font(.headline)
                    Text(name)
                        .font(.caption)
                        .opacity(0.75)
                }
                Spacer()
                if !locked {
                    Image(systemName: "chevron.right")
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(locked ? Color.white.opacity(0.08) : Color.orange.opacity(0.85),
                        in: RoundedRectangle(cornerRadius: 16))
            .foregroundStyle(.white)
        }
        .disabled(locked)
    }
}

// MARK: - HUD di gioco

struct HUDOverlay: View {
    @ObservedObject var viewModel: GameViewModel

    var body: some View {
        VStack {
            topBar
            Spacer()
            spellBar
        }
    }

    private var topBar: some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                viewModel.quitToMenu()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(.black.opacity(0.45), in: Circle())
            }

            VStack(spacing: 6) {
                StatBar(label: "🤴", fraction: viewModel.hud.heroHP, color: .green)
                StatBar(label: "🏰", fraction: viewModel.hud.gateHP, color: .red)
            }

            VStack(spacing: 4) {
                Text(timeString(viewModel.hud.timeLeft))
                    .font(.system(.headline, design: .monospaced))
                    .foregroundStyle(viewModel.hud.timeLeft < 20 ? .red : .white)
                Text("⚔️ \(viewModel.hud.allies)")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.85))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 10))
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var spellBar: some View {
        HStack(spacing: 22) {
            SpellButton(emoji: "🔥", title: "Fuoco",
                        cooldown: viewModel.hud.fireballCD) {
                viewModel.castFireball()
            }
            SpellButton(emoji: "💚", title: "Cura",
                        cooldown: viewModel.hud.healCD) {
                viewModel.castHeal()
            }
            SpellButton(emoji: "🛡️", title: "Evoca",
                        cooldown: viewModel.hud.summonCD) {
                viewModel.summonKnights()
            }
        }
        .padding(.bottom, 18)
    }

    private func timeString(_ t: TimeInterval) -> String {
        let seconds = Int(t.rounded(.up))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

struct StatBar: View {
    let label: String
    let fraction: CGFloat
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Text(label).font(.caption)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.black.opacity(0.5))
                    Capsule()
                        .fill(color)
                        .frame(width: max(0, geo.size.width * min(1, fraction)))
                }
            }
            .frame(height: 10)
        }
    }
}

struct SpellButton: View {
    let emoji: String
    let title: String
    /// 0 = pronto, 1 = appena lanciato.
    let cooldown: CGFloat
    let action: () -> Void

    private var isReady: Bool { cooldown <= 0.001 }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(.black.opacity(isReady ? 0.55 : 0.75))
                    Text(emoji)
                        .font(.system(size: 30))
                        .opacity(isReady ? 1 : 0.35)
                    Circle()
                        .trim(from: 0, to: cooldown)
                        .stroke(Color.white.opacity(0.9),
                                style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .padding(3)
                }
                .frame(width: 64, height: 64)
                .overlay(Circle().stroke(isReady ? Color.yellow : Color.white.opacity(0.25),
                                         lineWidth: 2))
                Text(title)
                    .font(.caption2.bold())
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
        .disabled(!isReady)
    }
}

// MARK: - Vittoria / Sconfitta

struct ResultOverlay: View {
    @ObservedObject var viewModel: GameViewModel

    private var isVictory: Bool { viewModel.screen == .victory }

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()

            VStack(spacing: 18) {
                Text(isVictory ? "🏆" : "💀")
                    .font(.system(size: 72))
                Text(isVictory ? "Vittoria!" : "Sconfitta")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundStyle(isVictory ? .yellow : .red)
                Text(isVictory
                     ? "Hai abbattuto il portone di \(viewModel.currentLevelName)!"
                     : "Il Re è caduto… riprova!")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)

                VStack(spacing: 12) {
                    if isVictory && viewModel.hasNextLevel {
                        ResultButton(title: "Prossimo livello ➡️", prominent: true) {
                            viewModel.nextLevel()
                        }
                    }
                    ResultButton(title: isVictory ? "Rigioca 🔁" : "Riprova 🔁",
                                 prominent: !isVictory) {
                        viewModel.retryLevel()
                    }
                    ResultButton(title: "Menu principale 🏠", prominent: false) {
                        viewModel.quitToMenu()
                    }
                }
                .padding(.top, 8)
            }
            .padding(28)
            .background(Color(red: 0.10, green: 0.12, blue: 0.22),
                        in: RoundedRectangle(cornerRadius: 24))
            .padding(.horizontal, 36)
        }
    }
}

struct ResultButton: View {
    let title: String
    let prominent: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(prominent ? Color.orange : Color.white.opacity(0.12),
                            in: RoundedRectangle(cornerRadius: 14))
                .foregroundStyle(.white)
        }
    }
}

#Preview {
    ContentView()
}
