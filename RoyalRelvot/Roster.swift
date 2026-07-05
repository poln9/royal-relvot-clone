import SpriteKit

// MARK: - Truppe evocabili dal giocatore

/// Le 10 truppe ispirate al roster del gioco originale
/// più 2 attaccanti inediti (Berserker e Drago).
enum PlayerTroop: String, CaseIterable {
    case cavaliere
    case arciere
    case paladino
    case piromante
    case gelomante
    case cannone
    case balestriere
    case mortaio
    case monaco
    case ogre
    case berserker
    case drago

    var emoji: String {
        switch self {
        case .cavaliere: return "⚔️"
        case .arciere: return "🏹"
        case .paladino: return "🛡️"
        case .piromante: return "🧙"
        case .gelomante: return "❄️"
        case .cannone: return "🧨"
        case .balestriere: return "🎯"
        case .mortaio: return "💣"
        case .monaco: return "🧘"
        case .ogre: return "🧌"
        case .berserker: return "🪓"
        case .drago: return "🐉"
        }
    }

    var displayName: String {
        switch self {
        case .cavaliere: return "Cavaliere"
        case .arciere: return "Arciere"
        case .paladino: return "Paladino"
        case .piromante: return "Piromante"
        case .gelomante: return "Gelomante"
        case .cannone: return "Cannone"
        case .balestriere: return "Balestriere"
        case .mortaio: return "Mortaio"
        case .monaco: return "Monaco"
        case .ogre: return "Ogre"
        case .berserker: return "Berserker"
        case .drago: return "Drago"
        }
    }

    var blurb: String {
        switch self {
        case .cavaliere: return "Mischia equilibrato"
        case .arciere: return "Tiro rapido a distanza"
        case .paladino: return "Tank da prima linea"
        case .piromante: return "Palle di fuoco ad area"
        case .gelomante: return "Rallenta i nemici"
        case .cannone: return "Demolisce le strutture"
        case .balestriere: return "Colpi precisi e potenti"
        case .mortaio: return "Bombarda da lontano"
        case .monaco: return "Cura gli alleati"
        case .ogre: return "Gigante devastante"
        case .berserker: return "Raffica di fendenti"
        case .drago: return "Vola e sputa fuoco"
        }
    }

    /// Livello a cui la truppa diventa disponibile.
    var unlockLevel: Int {
        switch self {
        case .cavaliere: return 1
        case .arciere: return 2
        case .paladino: return 3
        case .piromante: return 4
        case .gelomante: return 5
        case .cannone: return 6
        case .monaco: return 7
        case .balestriere: return 8
        case .mortaio: return 9
        case .ogre: return 10
        case .berserker: return 12
        case .drago: return 14
        }
    }

    /// Quante unità evoca una singola chiamata.
    var squadSize: Int {
        switch self {
        case .cavaliere, .arciere: return 3
        case .paladino, .piromante, .gelomante, .balestriere, .monaco, .berserker: return 2
        case .cannone, .mortaio, .ogre, .drago: return 1
        }
    }

    var summonCooldown: TimeInterval {
        switch self {
        case .cavaliere: return 8
        case .arciere: return 9
        case .paladino: return 10
        case .balestriere, .berserker: return 11
        case .piromante, .gelomante, .monaco: return 12
        case .cannone: return 13
        case .mortaio: return 14
        case .ogre: return 15
        case .drago: return 16
        }
    }

    func makeUnit() -> Unit {
        switch self {
        case .cavaliere:
            return Unit(team: .player, kind: .troop, emoji: emoji, size: 32,
                        hp: 160, damage: 13, attackRange: 50, aggroRange: 150,
                        moveSpeed: 250, attackInterval: 0.7, barWidth: 34)
        case .arciere:
            return Unit(team: .player, kind: .troop, emoji: emoji, size: 32,
                        hp: 90, damage: 11, attackRange: 190, aggroRange: 210,
                        moveSpeed: 230, attackInterval: 0.9,
                        traits: CombatTraits(projectileSpeed: 500), barWidth: 34)
        case .paladino:
            return Unit(team: .player, kind: .troop, emoji: emoji, size: 36,
                        hp: 280, damage: 16, attackRange: 50, aggroRange: 150,
                        moveSpeed: 220, attackInterval: 0.8, barWidth: 38)
        case .piromante:
            return Unit(team: .player, kind: .troop, emoji: emoji, size: 34,
                        hp: 110, damage: 20, attackRange: 170, aggroRange: 200,
                        moveSpeed: 210, attackInterval: 1.2,
                        traits: CombatTraits(projectileSpeed: 450, splashRadius: 60),
                        barWidth: 36)
        case .gelomante:
            return Unit(team: .player, kind: .troop, emoji: emoji, size: 34,
                        hp: 110, damage: 8, attackRange: 170, aggroRange: 200,
                        moveSpeed: 210, attackInterval: 1.0,
                        traits: CombatTraits(projectileSpeed: 450,
                                             slowFactor: 0.45, slowDuration: 2.5),
                        barWidth: 36)
        case .cannone:
            return Unit(team: .player, kind: .troop, emoji: emoji, size: 36,
                        hp: 180, damage: 30, attackRange: 210, aggroRange: 230,
                        moveSpeed: 140, attackInterval: 1.6,
                        traits: CombatTraits(projectileSpeed: 380, splashRadius: 40,
                                             structureDamageMultiplier: 2.5),
                        barWidth: 38)
        case .balestriere:
            return Unit(team: .player, kind: .troop, emoji: emoji, size: 32,
                        hp: 120, damage: 24, attackRange: 230, aggroRange: 250,
                        moveSpeed: 200, attackInterval: 1.4,
                        traits: CombatTraits(projectileSpeed: 600), barWidth: 34)
        case .mortaio:
            return Unit(team: .player, kind: .troop, emoji: emoji, size: 34,
                        hp: 140, damage: 36, attackRange: 280, aggroRange: 300,
                        moveSpeed: 120, attackInterval: 2.2,
                        traits: CombatTraits(projectileSpeed: 300, splashRadius: 80),
                        barWidth: 36)
        case .monaco:
            return Unit(team: .player, kind: .troop, emoji: emoji, size: 34,
                        hp: 150, damage: 30, attackRange: 150, aggroRange: 220,
                        moveSpeed: 230, attackInterval: 0.9,
                        traits: CombatTraits(healer: true), barWidth: 36)
        case .ogre:
            return Unit(team: .player, kind: .troop, emoji: emoji, size: 46,
                        hp: 650, damage: 45, attackRange: 60, aggroRange: 150,
                        moveSpeed: 140, attackInterval: 1.1, barWidth: 48)
        case .berserker:
            return Unit(team: .player, kind: .troop, emoji: emoji, size: 34,
                        hp: 130, damage: 16, attackRange: 45, aggroRange: 170,
                        moveSpeed: 300, attackInterval: 0.35, barWidth: 36)
        case .drago:
            return Unit(team: .player, kind: .troop, emoji: emoji, size: 46,
                        hp: 380, damage: 28, attackRange: 160, aggroRange: 220,
                        moveSpeed: 200, attackInterval: 1.0,
                        traits: CombatTraits(projectileSpeed: 420, splashRadius: 55,
                                             flying: true),
                        barWidth: 48)
        }
    }
}

// MARK: - Nemici mobili

enum Foe: CaseIterable {
    case goblin
    case bruto
    case lupo
    case tiratore
    case mummia
    case gargolla
    case negromante

    /// Livello a partire dal quale il nemico compare.
    var introLevel: Int {
        switch self {
        case .goblin: return 1
        case .bruto: return 2
        case .lupo: return 3
        case .tiratore: return 4
        case .mummia: return 7
        case .gargolla: return 10
        case .negromante: return 13
        }
    }

    static func available(at level: Int) -> [Foe] {
        allCases.filter { $0.introLevel <= level }
    }

    /// Nemici usati come rinforzi continui dal portone.
    static func raiders(at level: Int) -> [Foe] {
        var pool: [Foe] = [.goblin]
        if level >= 3 { pool.append(.lupo) }
        if level >= 5 { pool.append(.tiratore) }
        if level >= 10 { pool.append(.gargolla) }
        if level >= 13 { pool.append(.negromante) }
        return pool
    }

    func makeUnit(power: CGFloat, aggro: CGFloat = 300) -> Unit {
        switch self {
        case .goblin:
            return Unit(team: .enemy, kind: .foe, emoji: "👹", size: 34,
                        hp: 70 * power, damage: 9 * power, attackRange: 45,
                        aggroRange: aggro, moveSpeed: 150, attackInterval: 0.8,
                        barWidth: 36)
        case .bruto:
            return Unit(team: .enemy, kind: .foe, emoji: "👺", size: 44,
                        hp: 250 * power, damage: 21 * power, attackRange: 50,
                        aggroRange: aggro, moveSpeed: 110, attackInterval: 1.0,
                        barWidth: 44)
        case .lupo:
            return Unit(team: .enemy, kind: .foe, emoji: "🐺", size: 36,
                        hp: 110 * power, damage: 14 * power, attackRange: 45,
                        aggroRange: aggro, moveSpeed: 240, attackInterval: 0.6,
                        barWidth: 38)
        case .tiratore:
            return Unit(team: .enemy, kind: .foe, emoji: "🦹", size: 34,
                        hp: 90 * power, damage: 12 * power, attackRange: 200,
                        aggroRange: max(aggro, 220), moveSpeed: 140, attackInterval: 1.1,
                        traits: CombatTraits(projectileSpeed: 480), barWidth: 36)
        case .mummia:
            return Unit(team: .enemy, kind: .foe, emoji: "🧟", size: 42,
                        hp: 420 * power, damage: 18 * power, attackRange: 50,
                        aggroRange: aggro, moveSpeed: 80, attackInterval: 1.2,
                        barWidth: 44)
        case .gargolla:
            return Unit(team: .enemy, kind: .foe, emoji: "🦇", size: 34,
                        hp: 70 * power, damage: 45 * power, attackRange: 55,
                        aggroRange: max(aggro, 400), moveSpeed: 260, attackInterval: 0.5,
                        traits: CombatTraits(splashRadius: 70, kamikaze: true, flying: true),
                        barWidth: 36)
        case .negromante:
            return Unit(team: .enemy, kind: .foe, emoji: "🧛", size: 36,
                        hp: 130 * power, damage: 24 * power, attackRange: 210,
                        aggroRange: max(aggro, 230), moveSpeed: 120, attackInterval: 1.5,
                        traits: CombatTraits(projectileSpeed: 420), barWidth: 38)
        }
    }
}

// MARK: - Torri difensive

enum TowerKind: CaseIterable {
    case freccia
    case bomba
    case gelo
    case serpe
    case fuoco
    case teschio

    var introLevel: Int {
        switch self {
        case .freccia: return 1
        case .bomba: return 3
        case .gelo: return 5
        case .serpe: return 8
        case .fuoco: return 11
        case .teschio: return 15
        }
    }

    static func available(at level: Int) -> [TowerKind] {
        allCases.filter { $0.introLevel <= level }
    }

    /// Piccola icona sopra la torre che ne indica il tipo.
    var badge: String {
        switch self {
        case .freccia: return "🏹"
        case .bomba: return "💣"
        case .gelo: return "❄️"
        case .serpe: return "🐍"
        case .fuoco: return "🔥"
        case .teschio: return "💀"
        }
    }

    func makeUnit(power: CGFloat) -> Unit {
        switch self {
        case .freccia:
            return Unit(team: .enemy, kind: .tower, emoji: "🗼", badge: badge, size: 54,
                        hp: 260 * power, damage: 16 * power, attackRange: 250,
                        aggroRange: 250, moveSpeed: 0, attackInterval: 1.15,
                        traits: CombatTraits(projectileSpeed: 420), barWidth: 52)
        case .bomba:
            return Unit(team: .enemy, kind: .tower, emoji: "🗼", badge: badge, size: 54,
                        hp: 300 * power, damage: 22 * power, attackRange: 220,
                        aggroRange: 220, moveSpeed: 0, attackInterval: 1.8,
                        traits: CombatTraits(projectileSpeed: 320, splashRadius: 70),
                        barWidth: 52)
        case .gelo:
            return Unit(team: .enemy, kind: .tower, emoji: "🗼", badge: badge, size: 54,
                        hp: 260 * power, damage: 8 * power, attackRange: 230,
                        aggroRange: 230, moveSpeed: 0, attackInterval: 1.2,
                        traits: CombatTraits(projectileSpeed: 420,
                                             slowFactor: 0.5, slowDuration: 2),
                        barWidth: 52)
        case .serpe:
            return Unit(team: .enemy, kind: .tower, emoji: "🗼", badge: badge, size: 54,
                        hp: 280 * power, damage: 6 * power, attackRange: 220,
                        aggroRange: 220, moveSpeed: 0, attackInterval: 1.0,
                        traits: CombatTraits(projectileSpeed: 420,
                                             poisonDPS: 10 * power, poisonDuration: 3),
                        barWidth: 52)
        case .fuoco:
            return Unit(team: .enemy, kind: .tower, emoji: "🗼", badge: badge, size: 54,
                        hp: 320 * power, damage: 40 * power, attackRange: 280,
                        aggroRange: 280, moveSpeed: 0, attackInterval: 1.7,
                        traits: CombatTraits(projectileSpeed: 520), barWidth: 52)
        case .teschio:
            return Unit(team: .enemy, kind: .tower, emoji: "🗼", badge: badge, size: 54,
                        hp: 380 * power, damage: 30 * power, attackRange: 200,
                        aggroRange: 200, moveSpeed: 0, attackInterval: 2.0,
                        traits: CombatTraits(projectileSpeed: 300, splashRadius: 90),
                        barWidth: 52)
        }
    }
}
