import SpriteKit

enum Team {
    case player
    case enemy
}

enum UnitKind {
    case hero
    case knight
    case goblin
    case brute
    case tower
    case gate
}

/// Unità di gioco generica: eroe, truppe, nemici, torri e portone
/// condividono lo stesso modello (HP, danno, gittata, velocità).
/// Le strutture statiche (torri, portone) hanno moveSpeed == 0.
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
    /// 0 = attacco in mischia, > 0 = velocità del proiettile
    let projectileSpeed: CGFloat

    var attackCooldown: TimeInterval = 0
    var isStatic: Bool { moveSpeed == 0 }
    var isAlive: Bool { hp > 0 }

    private let body = SKLabelNode()
    private let barBack: SKSpriteNode
    private let barFill: SKSpriteNode
    private let barWidth: CGFloat

    init(team: Team,
         kind: UnitKind,
         emoji: String,
         size: CGFloat,
         hp: CGFloat,
         damage: CGFloat,
         attackRange: CGFloat,
         aggroRange: CGFloat,
         moveSpeed: CGFloat,
         attackInterval: TimeInterval,
         projectileSpeed: CGFloat = 0,
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
        self.projectileSpeed = projectileSpeed
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

        let barY = size * 0.78
        barBack.position = CGPoint(x: 0, y: barY)
        addChild(barBack)
        barFill.anchorPoint = CGPoint(x: 0, y: 0.5)
        barFill.position = CGPoint(x: -(barWidth - 2) / 2, y: barY)
        addChild(barFill)

        zPosition = 10
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) non supportato") }

    /// Applica danno; ritorna true se l'unità è morta con questo colpo.
    @discardableResult
    func applyDamage(_ amount: CGFloat) -> Bool {
        guard isAlive else { return false }
        hp = max(0, hp - amount)
        refreshBar()
        body.removeAction(forKey: "hit")
        body.run(.sequence([.scale(to: 1.2, duration: 0.06),
                            .scale(to: 1.0, duration: 0.08)]), withKey: "hit")
        return hp == 0
    }

    func heal(_ amount: CGFloat) {
        guard isAlive else { return }
        hp = min(maxHP, hp + amount)
        refreshBar()
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

    // MARK: - Factory

    static func hero() -> Unit {
        Unit(team: .player, kind: .hero, emoji: "🤴", size: 44,
             hp: 650, damage: 38, attackRange: 70, aggroRange: 85,
             moveSpeed: 270, attackInterval: 0.55, barWidth: 46)
    }

    static func knight() -> Unit {
        Unit(team: .player, kind: .knight, emoji: "⚔️", size: 32,
             hp: 160, damage: 13, attackRange: 50, aggroRange: 150,
             moveSpeed: 250, attackInterval: 0.7, barWidth: 34)
    }

    /// Le pattuglie usano l'aggro di default (ingaggiano solo da vicino);
    /// i rinforzi dal portone ricevono un aggro enorme per caricare l'eroe.
    static func goblin(power: CGFloat, aggro: CGFloat = 280) -> Unit {
        Unit(team: .enemy, kind: .goblin, emoji: "👹", size: 34,
             hp: 70 * power, damage: 9 * power, attackRange: 45, aggroRange: aggro,
             moveSpeed: 150, attackInterval: 0.8, barWidth: 36)
    }

    static func brute(power: CGFloat) -> Unit {
        Unit(team: .enemy, kind: .brute, emoji: "👺", size: 44,
             hp: 250 * power, damage: 21 * power, attackRange: 50, aggroRange: 300,
             moveSpeed: 110, attackInterval: 1.0, barWidth: 44)
    }

    static func tower(power: CGFloat) -> Unit {
        Unit(team: .enemy, kind: .tower, emoji: "🗼", size: 54,
             hp: 260 * power, damage: 16 * power, attackRange: 250, aggroRange: 250,
             moveSpeed: 0, attackInterval: 1.15, projectileSpeed: 420, barWidth: 52)
    }

    static func gate(hp: CGFloat) -> Unit {
        Unit(team: .enemy, kind: .gate, emoji: "🏰", size: 92,
             hp: hp, damage: 0, attackRange: 0, aggroRange: 0,
             moveSpeed: 0, attackInterval: 10, barWidth: 130)
    }
}

extension CGPoint {
    func distance(to other: CGPoint) -> CGFloat {
        let dx = other.x - x
        let dy = other.y - y
        return sqrt(dx * dx + dy * dy)
    }
}
