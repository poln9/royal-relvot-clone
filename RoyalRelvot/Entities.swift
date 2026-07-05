import SpriteKit

enum Team {
    case player
    case enemy
}

enum UnitKind {
    case hero
    case troop
    case foe
    case tower
    case barricade
    case gate
}

/// Tratti speciali di combattimento di un'unità.
struct CombatTraits {
    /// 0 = attacco in mischia, > 0 = velocità del proiettile.
    var projectileSpeed: CGFloat = 0
    /// Raggio del danno ad area all'impatto (0 = bersaglio singolo).
    var splashRadius: CGFloat = 0
    /// Fattore di rallentamento applicato al bersaglio (0 = nessuno, 0.5 = metà velocità).
    var slowFactor: CGFloat = 0
    var slowDuration: TimeInterval = 0
    /// Danno da veleno al secondo applicato al bersaglio (0 = nessuno).
    var poisonDPS: CGFloat = 0
    var poisonDuration: TimeInterval = 0
    /// Esplode al primo attacco, danneggiando l'area e morendo.
    var kamikaze: Bool = false
    /// Invece di attaccare cura l'alleato più ferito (damage = cura per colpo).
    var healer: Bool = false
    /// Ignora le barricate.
    var flying: Bool = false
    /// Moltiplicatore di danno contro strutture (torri, barricate, portone).
    var structureDamageMultiplier: CGFloat = 1
}

/// Unità di gioco generica: eroe, truppe, nemici, torri, barricate e portone
/// condividono lo stesso modello. Le strutture hanno moveSpeed == 0.
final class Unit: SKNode {
    let team: Team
    let kind: UnitKind
    let maxHP: CGFloat
    private(set) var hp: CGFloat
    let damage: CGFloat
    let attackRange: CGFloat
    let aggroRange: CGFloat
    let moveSpeed: CGFloat
    let attackInterval: TimeInterval
    let traits: CombatTraits

    var attackCooldown: TimeInterval = 0

    // Stato alterato (gestito dalla scena).
    var slowRemaining: TimeInterval = 0
    var slowFactor: CGFloat = 1
    var poisonRemaining: TimeInterval = 0
    var poisonDPS: CGFloat = 0

    var isStatic: Bool { moveSpeed == 0 }
    var isAlive: Bool { hp > 0 }
    var currentSpeed: CGFloat { slowRemaining > 0 ? moveSpeed * slowFactor : moveSpeed }

    private let body = SKLabelNode()
    private let statusLabel = SKLabelNode()
    private let barBack: SKSpriteNode
    private let barFill: SKSpriteNode
    private let barWidth: CGFloat

    init(team: Team,
         kind: UnitKind,
         emoji: String,
         badge: String? = nil,
         size: CGFloat,
         hp: CGFloat,
         damage: CGFloat,
         attackRange: CGFloat,
         aggroRange: CGFloat,
         moveSpeed: CGFloat,
         attackInterval: TimeInterval,
         traits: CombatTraits = CombatTraits(),
         barWidth: CGFloat = 40) {
        self.team = team
        self.kind = kind
        self.maxHP = hp
        self.hp = hp
        self.damage = damage
        self.attackRange = attackRange
        self.aggroRange = aggroRange
        self.moveSpeed = moveSpeed
        self.attackInterval = attackInterval
        self.traits = traits
        self.barWidth = barWidth
        self.barBack = SKSpriteNode(color: SKColor(white: 0, alpha: 0.55),
                                    size: CGSize(width: barWidth, height: 6))
        self.barFill = SKSpriteNode(color: team == .player ? .green : .red,
                                    size: CGSize(width: barWidth - 2, height: 4))
        super.init()

        body.text = emoji
        body.fontSize = size
        body.verticalAlignmentMode = .center
        body.horizontalAlignmentMode = .center
        addChild(body)

        if let badge {
            let badgeLabel = SKLabelNode(text: badge)
            badgeLabel.fontSize = 17
            badgeLabel.verticalAlignmentMode = .center
            badgeLabel.position = CGPoint(x: size * 0.38, y: size * 0.5)
            badgeLabel.zPosition = 1
            addChild(badgeLabel)
        }

        let barY = size * 0.78
        barBack.position = CGPoint(x: 0, y: barY)
        addChild(barBack)
        barFill.anchorPoint = CGPoint(x: 0, y: 0.5)
        barFill.position = CGPoint(x: -(barWidth - 2) / 2, y: barY)
        addChild(barFill)

        statusLabel.fontSize = 13
        statusLabel.verticalAlignmentMode = .center
        statusLabel.position = CGPoint(x: 0, y: barY + 11)
        addChild(statusLabel)

        zPosition = 10
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) non supportato") }

    /// Applica danno; ritorna true se l'unità è morta con questo colpo.
    @discardableResult
    func applyDamage(_ amount: CGFloat, flash: Bool = true) -> Bool {
        guard isAlive else { return false }
        hp = max(0, hp - amount)
        refreshBar()
        if flash {
            body.removeAction(forKey: "hit")
            body.run(.sequence([.scale(to: 1.2, duration: 0.06),
                                .scale(to: 1.0, duration: 0.08)]), withKey: "hit")
        }
        return hp == 0
    }

    func heal(_ amount: CGFloat) {
        guard isAlive else { return }
        hp = min(maxHP, hp + amount)
        refreshBar()
    }

    func refreshStatusIcon() {
        var icons = ""
        if slowRemaining > 0 { icons += "❄️" }
        if poisonRemaining > 0 { icons += "☠️" }
        statusLabel.text = icons
    }

    private func refreshBar() {
        barFill.xScale = maxHP > 0 ? hp / maxHP : 0
    }

    /// Piccolo affondo verso il bersaglio per rendere leggibile l'attacco in mischia.
    func lunge(toward point: CGPoint) {
        let dx = point.x - position.x
        let dy = point.y - position.y
        let len = max(1, sqrt(dx * dx + dy * dy))
        let offset = CGPoint(x: dx / len * 10, y: dy / len * 10)
        body.removeAction(forKey: "lunge")
        body.run(.sequence([.moveBy(x: offset.x, y: offset.y, duration: 0.07),
                            .moveBy(x: -offset.x, y: -offset.y, duration: 0.1)]), withKey: "lunge")
    }

    // MARK: - Factory delle unità speciali

    static func hero() -> Unit {
        Unit(team: .player, kind: .hero, emoji: "🤴", size: 44,
             hp: 650, damage: 38, attackRange: 70, aggroRange: 85,
             moveSpeed: 270, attackInterval: 0.55, barWidth: 46)
    }

    static func gate(hp: CGFloat) -> Unit {
        Unit(team: .enemy, kind: .gate, emoji: "🏰", size: 92,
             hp: hp, damage: 0, attackRange: 0, aggroRange: 0,
             moveSpeed: 0, attackInterval: 10, barWidth: 130)
    }

    static func barricade(power: CGFloat) -> Unit {
        Unit(team: .enemy, kind: .barricade, emoji: "🪵🪵🪵", size: 34,
             hp: 380 * power, damage: 0, attackRange: 0, aggroRange: 0,
             moveSpeed: 0, attackInterval: 10, barWidth: 110)
    }
}

extension CGPoint {
    func distance(to other: CGPoint) -> CGFloat {
        let dx = other.x - x
        let dy = other.y - y
        return sqrt(dx * dx + dy * dy)
    }
}
