import Foundation
import CoreGraphics

/// Definizione dati di un livello: lunghezza del sentiero, torri,
/// pattuglie, cadenza dei rinforzi nemici e vita del portone.
struct LevelDefinition {
    let name: String
    /// Lunghezza del sentiero in punti (il portone è alla fine).
    let length: CGFloat
    let timeLimit: TimeInterval
    /// Posizioni Y delle torri; il lato (sx/dx) si alterna automaticamente.
    let towerYs: [CGFloat]
    /// Posizioni Y delle pattuglie di guardia lungo il sentiero.
    let patrolYs: [CGFloat]
    /// Ogni quanti secondi il portone manda un goblin di rinforzo.
    let spawnInterval: TimeInterval
    let gateHP: CGFloat
    /// Moltiplicatore di HP e danno dei nemici.
    let enemyPower: CGFloat
    /// Se true le pattuglie includono anche un bruto.
    let includeBrutes: Bool

    static let all: [LevelDefinition] = [
        LevelDefinition(name: "Il Sentiero Verde",
                        length: 2200, timeLimit: 150,
                        towerYs: [700, 1300, 1800],
                        patrolYs: [500, 1000, 1500],
                        spawnInterval: 9, gateHP: 1300,
                        enemyPower: 1.0, includeBrutes: false),
        LevelDefinition(name: "La Gola dei Goblin",
                        length: 2800, timeLimit: 180,
                        towerYs: [600, 1100, 1600, 2100, 2450],
                        patrolYs: [450, 900, 1400, 1900, 2300],
                        spawnInterval: 7, gateHP: 1900,
                        enemyPower: 1.25, includeBrutes: true),
        LevelDefinition(name: "L'Assedio Finale",
                        length: 3400, timeLimit: 210,
                        towerYs: [500, 950, 1400, 1850, 2300, 2750, 3050],
                        patrolYs: [400, 800, 1250, 1700, 2150, 2600, 2950],
                        spawnInterval: 5.5, gateHP: 2600,
                        enemyPower: 1.5, includeBrutes: true),
    ]
}
