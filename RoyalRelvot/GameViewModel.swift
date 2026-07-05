import Foundation
import Combine

/// Coordina la navigazione tra menu e partita e fa da ponte
/// tra la scena SpriteKit e l'interfaccia SwiftUI.
final class GameViewModel: ObservableObject {

    enum Screen: Equatable {
        case menu
        case playing
        case victory
        case defeat
    }

    @Published var screen: Screen = .menu
    @Published var hud = HUDState()
    @Published private(set) var unlockedLevel: Int
    /// Livello selezionato nel menu, in attesa della scelta delle truppe.
    @Published var pendingLevel: Int?
    @Published private(set) var loadout: [PlayerTroop] = []
    @Published private(set) var progression: Progression
    /// True quando è aperto il negozio dei potenziamenti.
    @Published var showUpgrades = false
    /// Oro guadagnato con l'ultima vittoria (mostrato nell'overlay).
    @Published private(set) var lastReward = 0

    private(set) var currentLevel = 1
    private(set) var scene: GameScene?

    private static let unlockedKey = "unlockedLevel"
    private static let loadoutKey = "loadout"

    init() {
        let unlocked = max(1, UserDefaults.standard.integer(forKey: Self.unlockedKey))
        unlockedLevel = unlocked
        progression = Progression.load()
        loadout = Self.savedLoadout(unlockedLevel: unlocked)
    }

    var levelCount: Int { LevelDefinition.all.count }
    var hasNextLevel: Bool { currentLevel < levelCount }
    var currentLevelName: String { LevelDefinition.all[currentLevel - 1].name }
    var unlockedTroops: [PlayerTroop] {
        PlayerTroop.allCases.filter { $0.unlockLevel <= unlockedLevel }
    }

    private static func savedLoadout(unlockedLevel: Int) -> [PlayerTroop] {
        let raw = UserDefaults.standard.stringArray(forKey: loadoutKey) ?? []
        var troops = raw.compactMap(PlayerTroop.init(rawValue:))
            .filter { $0.unlockLevel <= unlockedLevel }
        if troops.isEmpty { troops = [.cavaliere] }
        return Array(troops.prefix(3))
    }

    // MARK: - Potenziamenti

    func buyUpgrade(_ kind: UpgradeKind) {
        let level = progression.level(of: kind)
        guard level < kind.maxLevel else { return }
        let cost = kind.cost(atLevel: level)
        guard progression.gold >= cost else { return }
        progression.gold -= cost
        progression.increment(kind)
        progression.save()
    }

    // MARK: - Navigazione

    func requestLevel(_ index: Int) {
        guard index <= unlockedLevel else { return }
        pendingLevel = index
    }

    func cancelLoadout() {
        pendingLevel = nil
    }

    func startPendingLevel(with chosen: [PlayerTroop]) {
        guard let index = pendingLevel else { return }
        pendingLevel = nil
        startLevel(index, loadout: chosen)
    }

    func startLevel(_ index: Int, loadout chosen: [PlayerTroop]) {
        guard (1...levelCount).contains(index), !chosen.isEmpty else { return }
        currentLevel = index
        loadout = chosen
        UserDefaults.standard.set(chosen.map(\.rawValue), forKey: Self.loadoutKey)
        hud = HUDState()

        let scene = GameScene(level: LevelDefinition.all[index - 1],
                              loadout: chosen,
                              config: BattleConfig(progression: progression))
        scene.onHUDUpdate = { [weak self] state in
            self?.hud = state
        }
        scene.onGameOver = { [weak self] victory in
            guard let self else { return }
            if victory {
                // Prima vittoria su questo livello = ricompensa piena.
                let firstTime = index >= self.unlockedLevel
                let reward = GoldReward.forVictory(level: index, firstTime: firstTime)
                self.lastReward = reward
                self.progression.gold += reward
                self.progression.save()
                let next = min(index + 1, self.levelCount)
                if next > self.unlockedLevel {
                    self.unlockedLevel = next
                    UserDefaults.standard.set(next, forKey: Self.unlockedKey)
                }
                self.screen = .victory
            } else {
                self.screen = .defeat
            }
        }
        self.scene = scene
        screen = .playing
    }

    func nextLevel() { startLevel(currentLevel + 1, loadout: loadout) }
    func retryLevel() { startLevel(currentLevel, loadout: loadout) }

    func quitToMenu() {
        scene = nil
        screen = .menu
    }

    // MARK: - Comandi di gioco

    func castFireball() { scene?.castFireball() }
    func castHeal() { scene?.castHeal() }
    func summonTroop(slot: Int) { scene?.summonTroop(slot: slot) }
}
