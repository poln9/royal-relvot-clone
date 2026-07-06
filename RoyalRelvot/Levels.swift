import Foundation
import CoreGraphics

struct TowerSpec {
    let kind: TowerKind
    let position: CGPoint
}

struct PatrolSpec {
    let position: CGPoint
    let foes: [Foe]
}

/// Definizione dati di un livello. Il mondo non è più un corridoio dritto:
/// è un insieme di corridoi percorribili (rettangoli di sabbia) che formano
/// curve a S e biforcazioni a diamante. La `road` è la spina dorsale a
/// waypoint che truppe e rinforzi seguono; l'eroe è libero di muoversi
/// ovunque nei corridoi, anche nei rami alternativi.
struct LevelDefinition {
    let name: String
    /// Coordinata Y del portone (fine del livello).
    let length: CGFloat
    let timeLimit: TimeInterval
    /// Aree percorribili (unione di rettangoli).
    let corridors: [CGRect]
    /// Waypoint della strada principale, dal campo (basso) al portone (alto).
    let road: [CGPoint]
    let towers: [TowerSpec]
    let patrols: [PatrolSpec]
    let barricadePoints: [CGPoint]
    /// Se true, l'accampamento nemico invia truppe regolarmente (dal liv. 4).
    let enemyCampActive: Bool
    let raiders: [Foe]
    let spawnInterval: TimeInterval
    let gateHP: CGFloat
    let enemyPower: CGFloat

    /// Posizione del portone.
    var gatePosition: CGPoint { road[road.count - 1] }

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

    // MARK: - Generatore

    private static func make(_ i: Int) -> LevelDefinition {
        var rng = SeededRandom(seed: UInt64(i) &* 7919)

        let targetLength: CGFloat = 2000 + CGFloat(i) * 160
        let half: CGFloat = 105

        var corridors: [CGRect] = []
        var road: [CGPoint] = [CGPoint(x: 0, y: 40)]
        var x: CGFloat = 0
        var y: CGFloat = 0

        func vertical(_ cx: CGFloat, from y0: CGFloat, to y1: CGFloat,
                      halfWidth: CGFloat = 105) {
            corridors.append(CGRect(x: cx - halfWidth, y: y0,
                                    width: halfWidth * 2, height: y1 - y0))
        }
        func horizontal(_ x0: CGFloat, _ x1: CGFloat, at cy: CGFloat) {
            let lo = min(x0, x1) - half
            let hi = max(x0, x1) + half
            corridors.append(CGRect(x: lo, y: cy - 95, width: hi - lo, height: 190))
        }

        // Tratto iniziale dritto con il campo del giocatore.
        vertical(x, from: -150, to: 450)
        y = 450
        road.append(CGPoint(x: x, y: y))

        while y < targetLength {
            let segH = CGFloat(430 + rng.int(150))
            let roll = rng.int(100)

            if i >= 3 && roll < 32 {
                // Biforcazione a diamante: due rami paralleli, la strada
                // principale ne sceglie uno; l'altro resta esplorabile.
                let top = y + max(segH, 520)
                horizontal(-150, 150, at: y + 95)
                vertical(-150, from: y, to: top, halfWidth: 92)
                vertical(150, from: y, to: top, halfWidth: 92)
                horizontal(-150, 150, at: top - 95)
                let side: CGFloat = rng.int(2) == 0 ? -150 : 150
                road.append(CGPoint(x: side, y: y + 95))
                road.append(CGPoint(x: side, y: top - 95))
                x = side
                y = top
                road.append(CGPoint(x: x, y: y))
            } else if roll < 70 {
                // Curva a S: il corridoio devia lateralmente a metà tratto.
                let dir: CGFloat = x > 40 ? -1 : (x < -40 ? 1 : (rng.int(2) == 0 ? 1 : -1))
                let newX = max(-170, min(170, x + dir * CGFloat(160 + rng.int(60))))
                let mid = y + segH * 0.55
                vertical(x, from: y, to: mid + 95)
                horizontal(x, newX, at: mid)
                vertical(newX, from: mid - 95, to: y + segH)
                road.append(CGPoint(x: x, y: mid))
                road.append(CGPoint(x: newX, y: mid))
                x = newX
                y += segH
                road.append(CGPoint(x: x, y: y))
            } else {
                // Tratto dritto.
                vertical(x, from: y, to: y + segH)
                y += segH
                road.append(CGPoint(x: x, y: y))
            }
        }

        // Tratto finale con il portone.
        vertical(x, from: y, to: y + 330)
        road.append(CGPoint(x: x, y: y + 160))
        road.append(CGPoint(x: x, y: y + 260))
        let length = y + 260

        // MARK: Posizionamenti lungo la strada

        let power: CGFloat = 1 + CGFloat(i - 1) * 0.12
        let gateHP: CGFloat = 1300 + CGFloat(i - 1) * 520

        // Lunghezze cumulative della polilinea per campionare posizioni.
        var cumulative: [CGFloat] = [0]
        for k in 1..<road.count {
            cumulative.append(cumulative[k - 1] + road[k].distance(to: road[k - 1]))
        }
        let totalLength = cumulative[cumulative.count - 1]

        func sample(at fraction: CGFloat) -> (point: CGPoint, dir: CGVector) {
            let target = fraction * totalLength
            var k = 1
            while k < road.count - 1 && cumulative[k] < target { k += 1 }
            let segLen = max(1, cumulative[k] - cumulative[k - 1])
            let t = (target - cumulative[k - 1]) / segLen
            let a = road[k - 1], b = road[k]
            let p = CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
            let d = CGVector(dx: (b.x - a.x) / segLen, dy: (b.y - a.y) / segLen)
            return (p, d)
        }

        // Torri: dentro i corridoi, sul bordo, alternando i lati.
        let towerKinds = TowerKind.available(at: i)
        let towerCount = min(2 + (i * 2) / 3, 14)
        var towers: [TowerSpec] = []
        for j in 0..<towerCount {
            let f = 0.15 + (0.82 - 0.15) * CGFloat(j) / CGFloat(max(1, towerCount - 1))
            let s = sample(at: f)
            let side: CGFloat = j % 2 == 0 ? -1 : 1
            let perp = CGVector(dx: -s.dir.dy, dy: s.dir.dx)
            let pos = CGPoint(x: s.point.x + perp.dx * 72 * side,
                              y: s.point.y + perp.dy * 72 * side)
            towers.append(TowerSpec(kind: towerKinds[rng.int(towerKinds.count)],
                                    position: pos))
        }

        // Pattuglie sulla strada.
        let foes = Foe.available(at: i)
        let patrolCount = min(3 + i / 2, 12)
        var patrols: [PatrolSpec] = []
        for j in 0..<patrolCount {
            let f = 0.12 + (0.88 - 0.12) * CGFloat(j) / CGFloat(max(1, patrolCount - 1))
            var squad: [Foe] = [.goblin]
            let extras = 1 + min(2, i / 6)
            for _ in 0..<extras {
                squad.append(foes[rng.int(foes.count)])
            }
            patrols.append(PatrolSpec(position: sample(at: f).point, foes: squad))
        }

        // Barricate: solo sui tratti verticali della strada.
        var barricades: [CGPoint] = []
        if i >= 4 {
            let count = min(1 + (i - 4) / 4, 4)
            var f: CGFloat = 0.3
            while barricades.count < count && f < 0.9 {
                let s = sample(at: f)
                if abs(s.dir.dy) > 0.9 {
                    barricades.append(s.point)
                    f += 0.55 / CGFloat(count)
                } else {
                    f += 0.04
                }
            }
        }

        return LevelDefinition(
            name: names[i - 1],
            length: length,
            timeLimit: min(160 + Double(i) * 13, 350),
            corridors: corridors,
            road: road,
            towers: towers,
            patrols: patrols,
            barricadePoints: barricades,
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
