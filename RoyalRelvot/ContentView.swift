import SwiftUI
import SpriteKit

struct ContentView: View {
    @StateObject private var viewModel = GameViewModel()

    var body: some View {
        ZStack {
            if viewModel.screen == .menu {
                MenuView(viewModel: viewModel)
                if let pending = viewModel.pendingLevel {
                    LoadoutView(viewModel: viewModel, levelIndex: pending)
                        .id(pending)
                        .transition(.move(edge: .bottom))
                }
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

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.10, green: 0.16, blue: 0.32),
                                    Color(red: 0.05, green: 0.07, blue: 0.15)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Text("👑")
                    .font(.system(size: 64))
                    .padding(.top, 12)
                Text("Royal Relvot")
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(colors: [.yellow, .orange],
                                       startPoint: .top, endPoint: .bottom))
                Text("Guida il Re fino al portone nemico!")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))

                ScrollView {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(1...viewModel.levelCount, id: \.self) { index in
                            LevelCell(index: index,
                                      locked: index > viewModel.unlockedLevel) {
                                viewModel.requestLevel(index)
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                }

                Text("Truppe sbloccate: \(viewModel.unlockedTroops.count)/\(PlayerTroop.allCases.count) · Clone didattico")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.45))
                    .padding(.bottom, 6)
            }
            .padding(.horizontal, 24)
        }
    }
}

struct LevelCell: View {
    let index: Int
    let locked: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(locked ? "🔒" : "\(index)")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                Text(LevelDefinition.all[index - 1].name)
                    .font(.system(size: 8))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .opacity(0.75)
            }
            .frame(maxWidth: .infinity, minHeight: 68)
            .background(locked ? Color.white.opacity(0.08) : Color.orange.opacity(0.85),
                        in: RoundedRectangle(cornerRadius: 14))
            .foregroundStyle(.white)
        }
        .disabled(locked)
    }
}

// MARK: - Preparazione esercito

struct LoadoutView: View {
    @ObservedObject var viewModel: GameViewModel
    let levelIndex: Int
    @State private var selection: [PlayerTroop]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    init(viewModel: GameViewModel, levelIndex: Int) {
        self.viewModel = viewModel
        self.levelIndex = levelIndex
        _selection = State(initialValue: viewModel.loadout)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.75).ignoresSafeArea()

            VStack(spacing: 14) {
                Text("Livello \(levelIndex) · \(LevelDefinition.all[levelIndex - 1].name)")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("Scegli fino a 3 truppe da portare in battaglia")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))

                ScrollView {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(PlayerTroop.allCases, id: \.self) { troop in
                            TroopCard(troop: troop,
                                      locked: troop.unlockLevel > viewModel.unlockedLevel,
                                      selected: selection.contains(troop)) {
                                toggle(troop)
                            }
                        }
                    }
                }
                .frame(maxHeight: 420)

                HStack(spacing: 12) {
                    Button("Annulla") {
                        viewModel.cancelLoadout()
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.12),
                                in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.white)

                    Button("Inizia battaglia ⚔️") {
                        viewModel.startPendingLevel(with: selection)
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(selection.isEmpty ? Color.gray : Color.orange,
                                in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.white)
                    .disabled(selection.isEmpty)
                }
            }
            .padding(20)
            .background(Color(red: 0.10, green: 0.12, blue: 0.22),
                        in: RoundedRectangle(cornerRadius: 24))
            .padding(.horizontal, 16)
        }
    }

    private func toggle(_ troop: PlayerTroop) {
        if let i = selection.firstIndex(of: troop) {
            selection.remove(at: i)
        } else if troop.unlockLevel <= viewModel.unlockedLevel && selection.count < 3 {
            selection.append(troop)
        }
    }
}

struct TroopCard: View {
    let troop: PlayerTroop
    let locked: Bool
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(locked ? "🔒" : troop.emoji)
                    .font(.system(size: 30))
                Text(troop.displayName)
                    .font(.caption.bold())
                Text(locked ? "Liv. \(troop.unlockLevel)" : troop.blurb)
                    .font(.system(size: 9))
                    .opacity(0.7)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                if !locked {
                    Text("x\(troop.squadSize) · \(Int(troop.summonCooldown))s")
                        .font(.system(size: 9, weight: .bold))
                        .opacity(0.6)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 96)
            .padding(6)
            .background(locked ? Color.white.opacity(0.06) : Color.white.opacity(0.12),
                        in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14)
                .stroke(selected ? Color.yellow : Color.clear, lineWidth: 3))
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
            actionBar
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

    private var actionBar: some View {
        HStack(spacing: 12) {
            SpellButton(emoji: "🔥", title: "Fuoco", size: 56,
                        cooldown: viewModel.hud.fireballCD) {
                viewModel.castFireball()
            }
            SpellButton(emoji: "💚", title: "Cura", size: 56,
                        cooldown: viewModel.hud.healCD) {
                viewModel.castHeal()
            }

            Rectangle()
                .fill(.white.opacity(0.3))
                .frame(width: 1, height: 44)

            ForEach(Array(viewModel.loadout.enumerated()), id: \.offset) { i, troop in
                SpellButton(emoji: troop.emoji, title: troop.displayName, size: 56,
                            cooldown: i < viewModel.hud.slotCDs.count
                                ? viewModel.hud.slotCDs[i] : 0) {
                    viewModel.summonTroop(slot: i)
                }
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
    var size: CGFloat = 64
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
                        .font(.system(size: size * 0.47))
                        .opacity(isReady ? 1 : 0.35)
                    Circle()
                        .trim(from: 0, to: cooldown)
                        .stroke(Color.white.opacity(0.9),
                                style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .padding(3)
                }
                .frame(width: size, height: size)
                .overlay(Circle().stroke(isReady ? Color.yellow : Color.white.opacity(0.25),
                                         lineWidth: 2))
                Text(title)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)
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
