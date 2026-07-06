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
                if viewModel.showUpgrades {
                    UpgradeView(viewModel: viewModel)
                        .transition(.move(edge: .bottom))
                }
            } else {
                gameLayer
            }
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.screen)
        .onAppear {
            AudioManager.shared.playMusic("music_menu")
        }
    }

    @ViewBuilder
    private var gameLayer: some View {
        ZStack {
            if let scene = viewModel.scene {
                // .id forza una SpriteView nuova per ogni battaglia:
                // riusare la stessa view cambiando scena crashava su device.
                SpriteView(scene: scene, options: [.ignoresSiblingOrder])
                    .ignoresSafeArea()
                    .id(ObjectIdentifier(scene))
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

            VStack(spacing: 14) {
                HStack {
                    Text("💰 \(viewModel.progression.gold)")
                        .font(.headline)
                        .foregroundStyle(.yellow)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.35), in: Capsule())
                    Spacer()
                    Button {
                        viewModel.showUpgrades = true
                    } label: {
                        Label("Potenziamenti", systemImage: "arrow.up.circle.fill")
                            .font(.subheadline.bold())
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.purple.opacity(0.8), in: Capsule())
                            .foregroundStyle(.white)
                    }
                }
                .padding(.top, 6)

                Text("👑")
                    .font(.system(size: 56))
                Text("Royal Relvot")
                    .font(.system(size: 38, weight: .black, design: .rounded))
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

// MARK: - Negozio potenziamenti

struct UpgradeView: View {
    @ObservedObject var viewModel: GameViewModel

    var body: some View {
        ZStack {
            Color.black.opacity(0.75).ignoresSafeArea()

            VStack(spacing: 14) {
                HStack {
                    Text("Potenziamenti")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    Spacer()
                    Text("💰 \(viewModel.progression.gold)")
                        .font(.headline)
                        .foregroundStyle(.yellow)
                }

                ForEach(UpgradeKind.allCases, id: \.self) { kind in
                    UpgradeRow(kind: kind,
                               level: viewModel.progression.level(of: kind),
                               gold: viewModel.progression.gold) {
                        viewModel.buyUpgrade(kind)
                    }
                }

                Button("Chiudi") {
                    viewModel.showUpgrades = false
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.12),
                            in: RoundedRectangle(cornerRadius: 14))
                .foregroundStyle(.white)
            }
            .padding(20)
            .background(Color(red: 0.10, green: 0.12, blue: 0.22),
                        in: RoundedRectangle(cornerRadius: 24))
            .padding(.horizontal, 16)
        }
    }
}

struct UpgradeRow: View {
    let kind: UpgradeKind
    let level: Int
    let gold: Int
    let action: () -> Void

    private var isMaxed: Bool { level >= kind.maxLevel }
    private var cost: Int { kind.cost(atLevel: level) }

    var body: some View {
        HStack(spacing: 10) {
            Text(kind.emoji).font(.system(size: 26))
            VStack(alignment: .leading, spacing: 2) {
                Text("\(kind.title) · Liv. \(level)/\(kind.maxLevel)")
                    .font(.subheadline.bold())
                Text(kind.subtitle)
                    .font(.caption2)
                    .opacity(0.7)
            }
            Spacer()
            Button(action: action) {
                Text(isMaxed ? "MAX" : "💰\(cost)")
                    .font(.caption.bold())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(isMaxed || gold < cost
                                ? Color.white.opacity(0.1) : Color.green.opacity(0.8),
                                in: Capsule())
            }
            .disabled(isMaxed || gold < cost)
        }
        .foregroundStyle(.white)
        .padding(10)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
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
                Text("Scegli fino a 3 truppe · le evochi spendendo elisir 🧪")
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
                    Text("x\(troop.squadSize) · 🧪\(troop.elixirCost)")
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
            ElixirBar(value: viewModel.hud.elixir, maxValue: viewModel.hud.elixirMax)
                .padding(.horizontal, 40)
                .padding(.bottom, 6)
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
                TroopButton(troop: troop,
                            affordable: viewModel.hud.elixir >= CGFloat(troop.elixirCost)) {
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

/// Barra dell'elisir in stile pozione: si riempie col tempo.
struct ElixirBar: View {
    let value: CGFloat
    let maxValue: CGFloat

    var body: some View {
        HStack(spacing: 8) {
            Text("🧪").font(.system(size: 18))
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.black.opacity(0.55))
                    Capsule()
                        .fill(LinearGradient(colors: [.purple, .pink],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(0, geo.size.width
                                          * min(1, maxValue > 0 ? value / maxValue : 0)))
                    // Tacche per ogni punto elisir.
                    HStack(spacing: 0) {
                        ForEach(1..<Int(maxValue.rounded()), id: \.self) { _ in
                            Spacer()
                            Rectangle()
                                .fill(.black.opacity(0.4))
                                .frame(width: 1)
                        }
                        Spacer()
                    }
                }
            }
            .frame(height: 16)
            .clipShape(Capsule())
            Text("\(Int(value))/\(Int(maxValue))")
                .font(.system(.caption, design: .monospaced).bold())
                .foregroundStyle(.white)
        }
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

/// Pulsante di evocazione: mostra il costo in elisir, disabilitato
/// quando l'elisir non basta.
struct TroopButton: View {
    let troop: PlayerTroop
    let affordable: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack(alignment: .bottomTrailing) {
                    ZStack {
                        Circle()
                            .fill(.black.opacity(affordable ? 0.55 : 0.75))
                        Text(troop.emoji)
                            .font(.system(size: 26))
                            .opacity(affordable ? 1 : 0.35)
                    }
                    .frame(width: 56, height: 56)
                    .overlay(Circle().stroke(affordable ? Color.pink : Color.white.opacity(0.25),
                                             lineWidth: 2))
                    Text("\(troop.elixirCost)")
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(.white)
                        .frame(width: 20, height: 20)
                        .background(affordable ? Color.pink : Color.gray, in: Circle())
                        .offset(x: 3, y: 3)
                }
                Text(troop.displayName)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)
            }
        }
        .disabled(!affordable)
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
                if isVictory {
                    Text("+\(viewModel.lastReward) 💰")
                        .font(.title3.bold())
                        .foregroundStyle(.yellow)
                }

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
