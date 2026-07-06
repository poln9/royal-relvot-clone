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

/// Genere di danno inflitto da un attacco. Ogni unità può essere
/// vulnerabile (danno x1.5), neutra (x1) o resistente (x0.6).
enum DamageKind {
    case taglio
    case perforante
    case esplosivo
    case magico
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
}

/// Unità di gioco generica: eroe, truppe, nemici, torri, barricate e portone
/// condividono lo stesso modello. Le strutture hanno moveSpeed == 0.
final class Unit: SKNode {
    let team: Team
    let kind: UnitKind
    let maxHP: CGFloat
    private(set) var hp: CGFloat
    let damage: CGFloat
    /// Genere del danno inflitto (nil per curatori e strutture inermi).
    let damageKind: DamageKind?
    /// Generi di danno che infliggono il 150% a questa unità.
    let vulnerabilities: Set<DamageKind>
    /// Generi di danno che infliggono il 60% a questa unità.
    let resistances: Set<DamageKind>
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

    // Navigazione lungo la strada del livello (gestita dalla scena).
    var roadIndex: Int = -1
    /// Ultimo istante (tempo di gioco) in cui l'unità si è mossa.
    var lastWalkAt: TimeInterval = -1

    var isStatic: Bool { moveSpeed == 0 }
    var isAlive: Bool { hp > 0 }
    var currentSpeed: CGFloat { slowRemaining > 0 ? moveSpeed * slowFactor : moveSpeed }

    /// Raggio usato dalla risoluzione delle collisioni (niente sovrapposizioni).
    let collisionRadius: CGFloat

    private let body: SKNode
    private var bodyBaseScale: CGFloat = 1
    private let statusLabel = SKLabelNode()
    private let barBack: SKSpriteNode
    private let barFill: SKSpriteNode
    private let barWidth: CGFloat

    init(team: Team,
         kind: UnitKind,
         emoji: String,
         spriteName: String? = nil,
         tint: SKColor? = nil,
         tintBlend: CGFloat = 0.45,
         badge: String? = nil,
         size: CGFloat,
         hp: CGFloat,
         damage: CGFloat,
         damageKind: DamageKind? = nil,
         vulnerabilities: Set<DamageKind> = [],
         resistances: Set<DamageKind> = [],
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
        self.damageKind = damageKind
        self.vulnerabilities = vulnerabilities
        self.resistances = resistances
        self.attackRange = attackRange
        self.aggroRange = aggroRange
        self.moveSpeed = moveSpeed
        self.attackInterval = attackInterval
        self.traits = traits
        self.barWidth = barWidth
        self.collisionRadius = size * 0.42
        self.barBack = SKSpriteNode(color: SKColor(white: 0, alpha: 0.55),
                                    size: CGSize(width: barWidth, height: 6))
        self.barFill = SKSpriteNode(color: team == .player ? .green : .red,
                                    size: CGSize(width: barWidth - 2, height: 4))

        // Sprite se disponibile nel bundle, altrimenti fallback emoji.
        // La tinta differenzia le varianti della stessa figura base
        // (es. piromante arancio e gelomante ciano dallo stesso mago).
        if let spriteName, UIImage(named: spriteName) != nil {
            let texture = SKTexture(imageNamed: spriteName)
            let sprite = SKSpriteNode(texture: texture)
            let maxSide = max(texture.size().width, texture.size().height)
            if maxSide > 0 { sprite.setScale(size * 1.55 / maxSide) }
            if let tint {
                sprite.color = tint
                sprite.colorBlendFactor = tintBlend
            }
            self.body = sprite
        } else {
            let label = SKLabelNode()
            label.text = emoji
            label.fontSize = size
            label.verticalAlignmentMode = .center
            label.horizontalAlignmentMode = .center
            self.body = label
        }
        super.init()

        // Ombra a terra: ancora visivamente l'unità al terreno.
        let shadow = SKShapeNode(ellipseOf: CGSize(width: size * (traits.flying ? 0.5 : 0.8),
                                                   height: size * 0.26))
        shadow.fillColor = SKColor(white: 0, alpha: 0.22)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 0, y: -size * (traits.flying ? 0.7 : 0.48))
        shadow.zPosition = -1
        addChild(shadow)

        // Le unità volanti fluttuano un po' più in alto.
        if traits.flying { body.position.y += 8 }

        addChild(body)
        bodyBaseScale = body.xScale

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

    private var isWalking = false

    /// Animazione di camminata: dondolio + passo molleggiato.
    func setWalking(_ walking: Bool) {
        guard walking != isWalking else { return }
        isWalking = walking
        if walking {
            let wobble = SKAction.repeatForever(.sequence([
                .group([.rotate(toAngle: 0.08, duration: 0.13),
                        .scaleY(to: 1.05, duration: 0.13)]),
                .group([.rotate(toAngle: -0.08, duration: 0.26),
                        .scaleY(to: 0.96, duration: 0.13)]),
                .rotate(toAngle: 0, duration: 0.13),
            ]))
            body.run(wobble, withKey: "walk")
        } else {
            body.removeAction(forKey: "walk")
            body.zRotation = 0
            body.yScale = abs(bodyBaseScale)
        }
    }

    /// Gira lo sprite verso la direzione di marcia (o del bersaglio).
    func face(dx: CGFloat) {
        guard abs(dx) > 4 else { return }
        let magnitude = abs(bodyBaseScale)
        body.xScale = dx < 0 ? -magnitude : magnitude
    }

    /// Entrata in scena: sbuca dal terreno con un piccolo rimbalzo.
    func playSpawn() {
        setScale(0.15)
        run(.sequence([.scale(to: 1.12, duration: 0.18),
                       .scale(to: 1.0, duration: 0.1)]))
    }

    /// Morte: l'unità si accascia di lato, poi svanisce.
    /// Il nodo si rimuove da solo a fine animazione.
    func playDeath() {
        removeAllActions()
        body.removeAllActions()
        let fallDirection: CGFloat = Bool.random() ? 1 : -1
        body.run(.group([.rotate(toAngle: fallDirection * .pi / 2, duration: 0.22),
                         .moveBy(x: 0, y: -6, duration: 0.22),
                         .scale(to: abs(bodyBaseScale) * 0.9, duration: 0.22)]))
        run(.sequence([.wait(forDuration: 0.3),
                       .fadeOut(withDuration: 0.35),
                       .removeFromParent()]))
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

    /// L'eroe con le statistiche derivate dai potenziamenti acquistati.
    /// Raggio corto: attacca solo ciò che è davvero adiacente e non
    /// insegue mai — il movimento resta sempre in mano al giocatore.
    static func hero(hp: CGFloat, damage: CGFloat) -> Unit {
        Unit(team: .player, kind: .hero, emoji: "🤴", spriteName: "hero", size: 44,
             hp: hp, damage: damage, damageKind: .taglio,
             attackRange: 62, aggroRange: 62,
             moveSpeed: 270, attackInterval: 0.55, barWidth: 46)
    }

    static func gate(hp: CGFloat) -> Unit {
        Unit(team: .enemy, kind: .gate, emoji: "🏰", spriteName: "gate", size: 92,
             hp: hp, damage: 0,
             vulnerabilities: [.esplosivo], resistances: [.perforante],
             attackRange: 0, aggroRange: 0,
             moveSpeed: 0, attackInterval: 10, barWidth: 130)
    }

    static func barricade(power: CGFloat) -> Unit {
        Unit(team: .enemy, kind: .barricade, emoji: "🪵🪵🪵", spriteName: "barricade", size: 88,
             hp: 350 * power, damage: 0,
             vulnerabilities: [.esplosivo], resistances: [.perforante],
             attackRange: 0, aggroRange: 0,
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
