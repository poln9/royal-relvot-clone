import SpriteKit

// MARK: - Truppe evocabili dal giocatore

/// Le 10 truppe ispirate al roster del gioco originale
/// più 2 attaccanti inediti (Berserker e Drago).
/// L'evocazione costa elisir; l'unico limite alle truppe in campo è l'elisir.
enum PlayerTroop: String, CaseIterable {
    case cavaliere
    case arciere
    case paladino
    case gelomante
    case monaco
    case piromante
    case balestriere
    case berserker
    case cannone
    case mortaio
    case ogre
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
        case .paladino: return "Tank, resiste alle frecce"
        case .piromante: return "Fuoco ad area"
        case .gelomante: return "Rallenta i nemici"
        case .cannone: return "Demolisce le strutture"
        case .balestriere: return "Colpi precisi e potenti"
        case .mortaio: return "Bombarda da lontano"
        case .monaco: return "Cura gli alleati"
        case .ogre: return "Gigante, resiste al taglio"
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

    /// Costo in elisir di una singola evocazione (l'intera squadra).
    var elixirCost: Int {
        switch self {
        case .cavaliere: return 1
        case .arciere: return 2
        case .paladino, .gelomante, .monaco: return 3
        case .piromante, .balestriere, .berserker: return 4
        case .cannone: return 5
        case .mortaio, .ogre: return 6
        case .drago: return 8
        }
    }

    /// Quante unità evoca una singola chiamata.
    var squadSize: Int {
        switch self {
        case .cavaliere, .arciere, .paladino, .balestriere, .berserker: return 2
        case .piromante, .gelomante, .monaco, .cannone, .mortaio, .ogre, .drago: return 1
        }
    }

    func makeUnit() -> Unit {
        switch self {
        case .cavaliere:
            return Unit(team: .player, kind: .troop, emoji: emoji,
                        spriteName: "unit_cavaliere", size: 32,
                        hp: 150, damage: 13, damageKind: .taglio,
                        attackRange: 50, aggroRange: 150,
                        moveSpeed: 250, attackInterval: 0.7, barWidth: 34)
        case .arciere:
            return Unit(team: .player, kind: .troop, emoji: emoji,
                        spriteName: "unit_arciere", size: 32,
                        hp: 85, damage: 12, damageKind: .perforante,
                        vulnerabilities: [.taglio],
                        attackRange: 190, aggroRange: 210,
                        moveSpeed: 230, attackInterval: 0.9,
                        traits: CombatTraits(projectileSpeed: 500), barWidth: 34)
        case .paladino:
            return Unit(team: .player, kind: .troop, emoji: emoji,
                        spriteName: "unit_paladino", size: 36,
                        hp: 300, damage: 15, damageKind: .taglio,
                        resistances: [.perforante],
                        attackRange: 50, aggroRange: 150,
                        moveSpeed: 220, attackInterval: 0.8, barWidth: 38)
        case .piromante:
            return Unit(team: .player, kind: .troop, emoji: emoji,
                        spriteName: "unit_piromante", size: 34,
                        hp: 120, damage: 24, damageKind: .magico,
                        vulnerabilities: [.taglio], resistances: [.magico],
                        attackRange: 170, aggroRange: 200,
                        moveSpeed: 210, attackInterval: 1.2,
                        traits: CombatTraits(projectileSpeed: 450, splashRadius: 60),
                        barWidth: 36)
        case .gelomante:
            return Unit(team: .player, kind: .troop, emoji: emoji,
                        spriteName: "unit_gelomante", size: 34,
                        hp: 120, damage: 8, damageKind: .magico,
                        vulnerabilities: [.taglio], resistances: [.magico],
                        attackRange: 170, aggroRange: 200,
                        moveSpeed: 210, attackInterval: 1.0,
                        traits: CombatTraits(projectileSpeed: 450,
                                             slowFactor: 0.45, slowDuration: 2.5),
                        barWidth: 36)
        case .cannone:
            return Unit(team: .player, kind: .troop, emoji: emoji,
                        spriteName: "unit_cannone", size: 36,
                        hp: 200, damage: 40, damageKind: .esplosivo,
                        vulnerabilities: [.magico], resistances: [.perforante],
                        attackRange: 210, aggroRange: 230,
                        moveSpeed: 140, attackInterval: 1.6,
                        traits: CombatTraits(projectileSpeed: 380, splashRadius: 40),
                        barWidth: 38)
        case .balestriere:
            return Unit(team: .player, kind: .troop, emoji: emoji,
                        spriteName: "unit_balestriere", size: 32,
                        hp: 110, damage: 26, damageKind: .perforante,
                        vulnerabilities: [.taglio],
                        attackRange: 230, aggroRange: 250,
                        moveSpeed: 200, attackInterval: 1.4,
                        traits: CombatTraits(projectileSpeed: 600), barWidth: 34)
        case .mortaio:
            return Unit(team: .player, kind: .troop, emoji: emoji,
                        spriteName: "unit_mortaio", size: 34,
                        hp: 150, damage: 42, damageKind: .esplosivo,
                        vulnerabilities: [.magico], resistances: [.perforante],
                        attackRange: 280, aggroRange: 300,
                        moveSpeed: 120, attackInterval: 2.2,
                        traits: CombatTraits(projectileSpeed: 300, splashRadius: 85),
                        barWidth: 36)
        case .monaco:
            return Unit(team: .player, kind: .troop, emoji: emoji,
                        spriteName: "unit_monaco", size: 34,
                        hp: 150, damage: 28,
                        vulnerabilities: [.perforante],
                        attackRange: 150, aggroRange: 220,
                        moveSpeed: 230, attackInterval: 0.9,
                        traits: CombatTraits(healer: true), barWidth: 36)
        case .ogre:
            return Unit(team: .player, kind: .troop, emoji: emoji,
                        spriteName: "unit_ogre", size: 46,
                        hp: 700, damage: 48, damageKind: .taglio,
                        vulnerabilities: [.magico], resistances: [.taglio],
                        attackRange: 60, aggroRange: 150,
                        moveSpeed: 140, attackInterval: 1.1, barWidth: 48)
        case .berserker:
            return Unit(team: .player, kind: .troop, emoji: emoji,
                        spriteName: "unit_berserker", size: 34,
                        hp: 140, damage: 15, damageKind: .taglio,
                        vulnerabilities: [.perforante],
                        attackRange: 45, aggroRange: 170,
                        moveSpeed: 300, attackInterval: 0.35, barWidth: 36)
        case .drago:
            return Unit(team: .player, kind: .troop, emoji: emoji,
                        spriteName: "unit_drago", size: 46,
                        hp: 420, damage: 30, damageKind: .magico,
                        vulnerabilities: [.perforante], resistances: [.magico],
                        attackRange: 160, aggroRange: 220,
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

    /// Nemici inviati regolarmente dall'accampamento nemico.
    static func raiders(at level: Int) -> [Foe] {
        var pool: [Foe] = [.goblin]
        if level >= 5 { pool.append(.lupo) }
        if level >= 6 { pool.append(.tiratore) }
        if level >= 10 { pool.append(.gargolla) }
        if level >= 13 { pool.append(.negromante) }
        return pool
    }

    func makeUnit(power: CGFloat, aggro: CGFloat = 300) -> Unit {
        switch self {
        case .goblin:
            return Unit(team: .enemy, kind: .foe, emoji: "👹",
                        spriteName: "foe_goblin", size: 34,
                        hp: 65 * power, damage: 9 * power, damageKind: .taglio,
                        attackRange: 45, aggroRange: aggro,
                        moveSpeed: 150, attackInterval: 0.8, barWidth: 36)
        case .bruto:
            return Unit(team: .enemy, kind: .foe, emoji: "👺",
                        spriteName: "foe_bruto", size: 44,
                        hp: 240 * power, damage: 20 * power, damageKind: .taglio,
                        vulnerabilities: [.magico], resistances: [.taglio],
                        attackRange: 50, aggroRange: aggro,
                        moveSpeed: 110, attackInterval: 1.0, barWidth: 44)
        case .lupo:
            return Unit(team: .enemy, kind: .foe, emoji: "🐺",
                        spriteName: "foe_lupo", size: 36,
                        hp: 100 * power, damage: 13 * power, damageKind: .taglio,
                        vulnerabilities: [.perforante],
                        attackRange: 45, aggroRange: aggro,
                        moveSpeed: 240, attackInterval: 0.55, barWidth: 38)
        case .tiratore:
            return Unit(team: .enemy, kind: .foe, emoji: "🦹",
                        spriteName: "foe_tiratore", size: 34,
                        hp: 85 * power, damage: 12 * power, damageKind: .perforante,
                        vulnerabilities: [.taglio],
                        attackRange: 200, aggroRange: max(aggro, 220),
                        moveSpeed: 140, attackInterval: 1.1,
                        traits: CombatTraits(projectileSpeed: 480), barWidth: 36)
        case .mummia:
            return Unit(team: .enemy, kind: .foe, emoji: "🧟",
                        spriteName: "foe_mummia", size: 42,
                        hp: 450 * power, damage: 17 * power, damageKind: .taglio,
                        vulnerabilities: [.magico], resistances: [.perforante, .taglio],
                        attackRange: 50, aggroRange: aggro,
                        moveSpeed: 75, attackInterval: 1.2, barWidth: 44)
        case .gargolla:
            return Unit(team: .enemy, kind: .foe, emoji: "🦇",
                        spriteName: "foe_gargolla", size: 34,
                        hp: 65 * power, damage: 42 * power, damageKind: .esplosivo,
                        vulnerabilities: [.perforante], resistances: [.esplosivo],
                        attackRange: 55, aggroRange: max(aggro, 400),
                        moveSpeed: 260, attackInterval: 0.5,
                        traits: CombatTraits(splashRadius: 70, kamikaze: true, flying: true),
                        barWidth: 36)
        case .negromante:
            return Unit(team: .enemy, kind: .foe, emoji: "🧛",
                        spriteName: "foe_negromante", size: 36,
                        hp: 125 * power, damage: 22 * power, damageKind: .magico,
                        vulnerabilities: [.taglio], resistances: [.magico],
                        attackRange: 210, aggroRange: max(aggro, 230),
                        moveSpeed: 120, attackInterval: 1.5,
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

    var spriteName: String {
        switch self {
        case .freccia: return "tower_freccia"
        case .bomba: return "tower_bomba"
        case .gelo: return "tower_gelo"
        case .serpe: return "tower_serpe"
        case .fuoco: return "tower_fuoco"
        case .teschio: return "tower_teschio"
        }
    }

    func makeUnit(power: CGFloat) -> Unit {
        // Tutte le torri sono strutture: vulnerabili all'esplosivo,
        // resistenti al perforante.
        switch self {
        case .freccia:
            return Unit(team: .enemy, kind: .tower, emoji: "🗼",
                        spriteName: spriteName, badge: badge, size: 54,
                        hp: 250 * power, damage: 15 * power, damageKind: .perforante,
                        vulnerabilities: [.esplosivo], resistances: [.perforante],
                        attackRange: 250, aggroRange: 250,
                        moveSpeed: 0, attackInterval: 1.15,
                        traits: CombatTraits(projectileSpeed: 420), barWidth: 52)
        case .bomba:
            return Unit(team: .enemy, kind: .tower, emoji: "🗼",
                        spriteName: spriteName, badge: badge, size: 54,
                        hp: 290 * power, damage: 22 * power, damageKind: .esplosivo,
                        vulnerabilities: [.esplosivo], resistances: [.perforante],
                        attackRange: 220, aggroRange: 220,
                        moveSpeed: 0, attackInterval: 1.8,
                        traits: CombatTraits(projectileSpeed: 320, splashRadius: 70),
                        barWidth: 52)
        case .gelo:
            return Unit(team: .enemy, kind: .tower, emoji: "🗼",
                        spriteName: spriteName, badge: badge, size: 54,
                        hp: 250 * power, damage: 8 * power, damageKind: .magico,
                        vulnerabilities: [.esplosivo], resistances: [.perforante],
                        attackRange: 230, aggroRange: 230,
                        moveSpeed: 0, attackInterval: 1.2,
                        traits: CombatTraits(projectileSpeed: 420,
                                             slowFactor: 0.5, slowDuration: 2),
                        barWidth: 52)
        case .serpe:
            return Unit(team: .enemy, kind: .tower, emoji: "🗼",
                        spriteName: spriteName, badge: badge, size: 54,
                        hp: 270 * power, damage: 6 * power, damageKind: .magico,
                        vulnerabilities: [.esplosivo], resistances: [.perforante],
                        attackRange: 220, aggroRange: 220,
                        moveSpeed: 0, attackInterval: 1.0,
                        traits: CombatTraits(projectileSpeed: 420,
                                             poisonDPS: 10 * power, poisonDuration: 3),
                        barWidth: 52)
        case .fuoco:
            return Unit(team: .enemy, kind: .tower, emoji: "🗼",
                        spriteName: spriteName, badge: badge, size: 54,
                        hp: 310 * power, damage: 38 * power, damageKind: .magico,
                        vulnerabilities: [.esplosivo], resistances: [.perforante],
                        attackRange: 280, aggroRange: 280,
                        moveSpeed: 0, attackInterval: 1.7,
                        traits: CombatTraits(projectileSpeed: 520), barWidth: 52)
        case .teschio:
            return Unit(team: .enemy, kind: .tower, emoji: "🗼",
                        spriteName: spriteName, badge: badge, size: 54,
                        hp: 370 * power, damage: 30 * power, damageKind: .esplosivo,
                        vulnerabilities: [.esplosivo], resistances: [.perforante],
                        attackRange: 200, aggroRange: 200,
                        moveSpeed: 0, attackInterval: 2.0,
                        traits: CombatTraits(projectileSpeed: 300, splashRadius: 90),
                        barWidth: 52)
        }
    }
}
