import Foundation
import CoreGraphics

/// Progressi permanenti del giocatore: oro e livelli dei potenziamenti.
struct Progression: Codable {
    var gold: Int = 0
    var heroHPLevel: Int = 0
    var heroAtkLevel: Int = 0
    /// Potenzia entrambi gli incantesimi (fuoco e cura) insieme.
    var spellLevel: Int = 0
    /// Ogni livello aggiunge +1 elisir massimo (base 6, fino a 20).
    var elixirMaxLevel: Int = 0
    /// Ogni livello aumenta dell'8% la velocità di rigenerazione.
    var elixirRateLevel: Int = 0

    private static let key = "progression"

    static func load() -> Progression {
        guard let data = UserDefaults.standard.data(forKey: key),
              let saved = try? JSONDecoder().decode(Progression.self, from: data) else {
            return Progression()
        }
        return saved
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }

    // MARK: - Valori derivati

    var heroHP: CGFloat { 600 * (1 + 0.15 * CGFloat(heroHPLevel)) }
    var heroDamage: CGFloat { 36 * (1 + 0.12 * CGFloat(heroAtkLevel)) }
    var fireballDamage: CGFloat { 80 * (1 + 0.18 * CGFloat(spellLevel)) }
    /// Frazione di vita massima ripristinata dalla cura.
    var healFraction: CGFloat { min(0.35 + 0.03 * CGFloat(spellLevel), 0.8) }
    var elixirMax: CGFloat { CGFloat(6 + elixirMaxLevel) }
    /// Elisir rigenerato al secondo.
    var elixirRate: CGFloat { 0.5 * (1 + 0.08 * CGFloat(elixirRateLevel)) }

    func level(of kind: UpgradeKind) -> Int {
        switch kind {
        case .heroHP: return heroHPLevel
        case .heroAtk: return heroAtkLevel
        case .spells: return spellLevel
        case .elixirMax: return elixirMaxLevel
        case .elixirRate: return elixirRateLevel
        }
    }

    mutating func increment(_ kind: UpgradeKind) {
        switch kind {
        case .heroHP: heroHPLevel += 1
        case .heroAtk: heroAtkLevel += 1
        case .spells: spellLevel += 1
        case .elixirMax: elixirMaxLevel += 1
        case .elixirRate: elixirRateLevel += 1
        }
    }
}

/// I potenziamenti acquistabili con l'oro delle vittorie.
enum UpgradeKind: CaseIterable {
    case heroHP
    case heroAtk
    case spells
    case elixirMax
    case elixirRate

    var emoji: String {
        switch self {
        case .heroHP: return "❤️"
        case .heroAtk: return "🗡️"
        case .spells: return "✨"
        case .elixirMax: return "🧪"
        case .elixirRate: return "⏩"
        }
    }

    var title: String {
        switch self {
        case .heroHP: return "Vita del Re"
        case .heroAtk: return "Attacco del Re"
        case .spells: return "Incantesimi"
        case .elixirMax: return "Elisir massimo"
        case .elixirRate: return "Velocità elisir"
        }
    }

    var subtitle: String {
        switch self {
        case .heroHP: return "+15% HP per livello"
        case .heroAtk: return "+12% danno per livello"
        case .spells: return "Potenzia fuoco e cura insieme"
        case .elixirMax: return "+1 elisir massimo (fino a 20)"
        case .elixirRate: return "+8% rigenerazione per livello"
        }
    }

    var maxLevel: Int {
        switch self {
        case .heroHP, .heroAtk, .spells: return 10
        case .elixirMax: return 14
        case .elixirRate: return 8
        }
    }

    func cost(atLevel level: Int) -> Int {
        switch self {
        case .heroHP, .heroAtk: return 120 + 90 * level
        case .spells: return 150 + 110 * level
        case .elixirMax: return 140 + 70 * level
        case .elixirRate: return 160 + 100 * level
        }
    }
}

/// Parametri della singola battaglia, derivati dalla progressione.
struct BattleConfig {
    let heroHP: CGFloat
    let heroDamage: CGFloat
    let fireballDamage: CGFloat
    let healFraction: CGFloat
    let elixirMax: CGFloat
    let elixirRate: CGFloat

    init(progression: Progression) {
        heroHP = progression.heroHP
        heroDamage = progression.heroDamage
        fireballDamage = progression.fireballDamage
        healFraction = progression.healFraction
        elixirMax = progression.elixirMax
        elixirRate = progression.elixirRate
    }
}

/// Ricompensa in oro per una vittoria.
enum GoldReward {
    static func forVictory(level: Int, firstTime: Bool) -> Int {
        firstTime ? 60 + 30 * level : 15 + 8 * level
    }
}
