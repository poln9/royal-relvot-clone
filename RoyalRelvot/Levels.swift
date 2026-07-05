import Foundation
import CoreGraphics

struct TowerSpec {
    let kind: TowerKind
    let y: CGFloat
    /// -1 = lato sinistro, +1 = lato destro.
    let side: CGFloat
}

struct PatrolSpec {
    let y: CGFloat
    let foes: [Foe]
}

/// Definizione dati di un livello. I 20 livelli sono generati
/// proceduralmente (in modo deterministico) con difficoltà crescente:
/// nuovi nemici e nuove torri vengono introdotti man mano.
struct LevelDefinition {
    let name: String
    let length: CGFloat
    let timeLimit: TimeInterval
    let towers: [TowerSpec]
    let patrols: [PatrolSpec]
    let barricadeYs: [CGFloat]
    /// Se true, l'accampamento nemico vicino al portone invia truppe
    /// regolarmente (dal livello 4 in poi).
    let enemyCampActive: Bool
    /// Ciclo dei nemici inviati dall'accampamento nemico.
    let raiders: [Foe]
    let spawnInterval: TimeInterval
    let gateHP: CGFloat
    let enemyPower: CGFloat

    static let all: [LevelDefinition] = (1...20).map(make)

    private static let names = [
        "Il Sentiero Verde",
        "Il Bosco dei Goblin",
        "Il Guado del Lupo",
        "Le Prime Mura",
        "La Gola dei Goblin",
        "Il Ponte Spezzato",
        "Le Sabbie della Mummia",
        "Il Nido di Serpi",
        "La Palude Nera",
        "Il Campanile delle Gargolle",
        "I Bastioni di Fuoco",
        "La Valle dei Caduti",
        "Il Circolo del Negromante",
        "Le Cripte Gelate",
        "La Torre del Teschio",
        "I Cancelli di Ferro",
        "La Marcia dei Mostri",
        "L'Ultimo Baluardo",
        "La Fortezza Oscura",
        "L'Assedio Finale",
    ]

    private static func make(_ i: Int) -> LevelDefinition {
        var rng = SeededRandom(seed: UInt64(i) &* 7919)

        let length: CGFloat = 2000 + CGFloat(i) * 160
        let timeLimit: TimeInterval = min(150 + Double(i) * 12, 330)
        let power: CGFloat = 1 + CGFloat(i - 1) * 0.12
        let gateHP: CGFloat = 1300 + CGFloat(i - 1) * 520

        // Torri: numero crescente, tipi pescati tra quelli già introdotti.
        let towerKinds = TowerKind.available(at: i)
        let towerCount = min(2 + (i * 2) / 3, 14)
        var towers: [TowerSpec] = []
        let towerTop = length - 320
        for j in 0..<towerCount {
            let frac = CGFloat(j + 1) / CGFloat(towerCount + 1)
            let y = 420 + frac * (towerTop - 420)
            let kind = towerKinds[rng.int(towerKinds.count)]
            towers.append(TowerSpec(kind: kind, y: y, side: j % 2 == 0 ? -1 : 1))
        }

        // Pattuglie: squadre miste dei nemici disponibili.
        let foes = Foe.available(at: i)
        let patrolCount = min(3 + i / 2, 12)
        var patrols: [PatrolSpec] = []
        let patrolTop = length - 700
        for j in 0..<patrolCount {
            let frac = patrolCount > 1 ? CGFloat(j) / CGFloat(patrolCount - 1) : 0
            let y = 380 + frac * (patrolTop - 380)
            var squad: [Foe] = [.goblin]
            let extras = 1 + min(2, i / 6)
            for _ in 0..<extras {
                squad.append(foes[rng.int(foes.count)])
            }
            patrols.append(PatrolSpec(y: y, foes: squad))
        }

        // Barricate sul sentiero dal livello 4 in poi.
        var barricadeYs: [CGFloat] = []
        if i >= 4 {
            let count = min(1 + (i - 4) / 4, 4)
            for j in 0..<count {
                let frac = CGFloat(j + 1) / CGFloat(count + 1)
                barricadeYs.append(500 + frac * (length - 1100))
            }
        }

        return LevelDefinition(
            name: names[i - 1],
            length: length,
            timeLimit: timeLimit,
            towers: towers,
            patrols: patrols,
            barricadeYs: barricadeYs,
            enemyCampActive: i >= 4,
            raiders: Foe.raiders(at: i),
            spawnInterval: max(10 - Double(i) * 0.3, 3.5),
            gateHP: gateHP,
            enemyPower: power)
    }
}

/// Generatore pseudo-casuale deterministico (SplitMix64): i livelli
/// risultano identici a ogni avvio dell'app.
private struct SeededRandom {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    mutating func int(_ upperBound: Int) -> Int {
        guard upperBound > 0 else { return 0 }
        return Int(next() % UInt64(upperBound))
    }
}
