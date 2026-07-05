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

    private(set) var currentLevel = 1
    private(set) var scene: GameScene?

    private static let unlockedKey = "unlockedLevel"

    init() {
        unlockedLevel = max(1, UserDefaults.standard.integer(forKey: Self.unlockedKey))
    }

    var levelCount: Int { LevelDefinition.all.count }
    var hasNextLevel: Bool { currentLevel < levelCount }
    var currentLevelName: String { LevelDefinition.all[currentLevel - 1].name }

    func startLevel(_ index: Int) {
        guard (1...levelCount).contains(index) else { return }
        currentLevel = index
        hud = HUDState()

        let scene = GameScene(level: LevelDefinition.all[index - 1])
        scene.onHUDUpdate = { [weak self] state in
            self?.hud = state
        }
        scene.onGameOver = { [weak self] victory in
            guard let self else { return }
            if victory {
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

    func nextLevel() { startLevel(currentLevel + 1) }
    func retryLevel() { startLevel(currentLevel) }

    func quitToMenu() {
        scene = nil
        screen = .menu
    }

    // MARK: - Incantesimi

    func castFireball() { scene?.castFireball() }
    func castHeal() { scene?.castHeal() }
    func summonKnights() { scene?.summonKnights() }
}
