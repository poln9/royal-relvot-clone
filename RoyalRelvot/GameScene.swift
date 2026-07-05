import SpriteKit

/// Stato sintetico mostrato dall'HUD SwiftUI, aggiornato dalla scena.
struct HUDState {
    var heroHP: CGFloat = 1
    var gateHP: CGFloat = 1
    var timeLeft: TimeInterval = 0
    var allies: Int = 0
    var elixir: CGFloat = 0
    var elixirMax: CGFloat = 6
    /// Frazione di cooldown residuo (0 = pronto, 1 = appena lanciato).
    var fireballCD: CGFloat = 0
    var healCD: CGFloat = 0
}

/// Scena principale: il Re avanza lungo il sentiero verticale verso il
/// portone nemico. Le truppe evocate partono dall'accampamento alla base
/// del sentiero e costano elisir; l'elisir si rigenera nel tempo.
final class GameScene: SKScene {

    let level: LevelDefinition
    let loadout: [PlayerTroop]
    let config: BattleConfig
    var onHUDUpdate: ((HUDState) -> Void)?
    var onGameOver: ((Bool) -> Void)?

    private var hero: Unit!
    private var gate: Unit!
    private var units: [Unit] = []
    private let cam = SKCameraNode()

    private var moveTarget: CGPoint?
    private var lastUpdateTime: TimeInterval = 0
    private var elapsed: TimeInterval = 0
    private var spawnAccumulator: TimeInterval = 0
    private var hudAccumulator: TimeInterval = 0
    private var raiderIndex = 0
    private var isGameOver = false

    private var elixir: CGFloat
    private var fireballReadyAt: TimeInterval = 0
    private var healReadyAt: TimeInterval = 0
    private let fireballCooldown: TimeInterval = 8
    private let healCooldown: TimeInterval = 15

    private let pathHalfWidth: CGFloat = 150
    /// Limite tecnico ai nemici in campo (per le prestazioni).
    private let maxRaiders = 18
    /// Punto di evocazione delle truppe: l'accampamento del giocatore.
    private let campPosition = CGPoint(x: 0, y: 40)

    private let formationOffsets: [CGPoint] = [
        CGPoint(x: -45, y: -35), CGPoint(x: 45, y: -35),
        CGPoint(x: -70, y: 10),  CGPoint(x: 70, y: 10),
        CGPoint(x: -45, y: -80), CGPoint(x: 45, y: -80),
        CGPoint(x: 0, y: -100),  CGPoint(x: 0, y: 60),
        CGPoint(x: -90, y: -55), CGPoint(x: 90, y: -55),
        CGPoint(x: -20, y: -130), CGPoint(x: 20, y: 90),
        CGPoint(x: -60, y: -110), CGPoint(x: 60, y: -110),
        CGPoint(x: -100, y: 30), CGPoint(x: 100, y: 30),
    ]

    /// Parametri di un colpo, catturati al momento dell'attacco così che
    /// il danno resti valido anche se l'attaccante muore nel frattempo.
    private struct HitPayload {
        let team: Team
        let damage: CGFloat
        let damageKind: DamageKind?
        let traits: CombatTraits
    }

    init(level: LevelDefinition, loadout: [PlayerTroop], config: BattleConfig) {
        self.level = level
        self.loadout = loadout
        self.config = config
        self.elixir = config.elixirMax
        super.init(size: CGSize(width: 430, height: 932))
        scaleMode = .aspectFill
        backgroundColor = SKColor(red: 0.24, green: 0.55, blue: 0.30, alpha: 1)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) non supportato") }

    // MARK: - Setup

    override func didMove(to view: SKView) {
        camera = cam
        addChild(cam)
        buildWorld()
        updateCamera()
        pushHUD()
    }

    private func buildWorld() {
        // Sentiero di terra battuta al centro, erba tutto intorno.
        let path = SKSpriteNode(color: SKColor(red: 0.76, green: 0.64, blue: 0.42, alpha: 1),
                                size: CGSize(width: pathHalfWidth * 2, height: level.length + 500))
        path.position = CGPoint(x: 0, y: level.length / 2)
        path.zPosition = 1
        addChild(path)

        // Decorazioni ai lati del sentiero.
        let decoEmoji = ["🌲", "🌳", "🪨", "🌲"]
        for i in 0..<40 {
            let deco = SKLabelNode(text: decoEmoji[i % decoEmoji.count])
            deco.fontSize = CGFloat.random(in: 26...40)
            let side: CGFloat = Bool.random() ? -1 : 1
            deco.position = CGPoint(x: side * CGFloat.random(in: 175...270),
                                    y: CGFloat.random(in: -100...(level.length + 100)))
            deco.zPosition = 2
            addChild(deco)
        }

        // Accampamento del giocatore: da qui partono le truppe evocate.
        let camp = SKLabelNode(text: "⛺")
        camp.fontSize = 44
        camp.position = CGPoint(x: -70, y: 20)
        camp.zPosition = 2
        addChild(camp)
        let flag = SKLabelNode(text: "🚩")
        flag.fontSize = 30
        flag.position = CGPoint(x: 70, y: 20)
        flag.zPosition = 2
        addChild(flag)

        // Mura ai lati del portone.
        let wallColor = SKColor(red: 0.45, green: 0.42, blue: 0.40, alpha: 1)
        for side: CGFloat in [-1, 1] {
            let wall = SKSpriteNode(color: wallColor, size: CGSize(width: 180, height: 46))
            wall.position = CGPoint(x: side * 155, y: level.length + 10)
            wall.zPosition = 3
            addChild(wall)
        }

        // Portone nemico in cima al sentiero.
        gate = Unit.gate(hp: level.gateHP)
        gate.position = CGPoint(x: 0, y: level.length)
        add(gate)

        // Accampamento nemico (attivo dal livello 4: invia truppe regolarmente).
        if level.enemyCampActive {
            let enemyCamp = SKLabelNode(text: "⛺")
            enemyCamp.fontSize = 40
            enemyCamp.position = CGPoint(x: -95, y: level.length - 90)
            enemyCamp.zPosition = 2
            addChild(enemyCamp)
        }

        // Torri difensive.
        for spec in level.towers {
            let tower = spec.kind.makeUnit(power: level.enemyPower)
            tower.position = CGPoint(x: spec.side * 125, y: spec.y)
            add(tower)
        }

        // Barricate che sbarrano il sentiero.
        for y in level.barricadeYs {
            let barricade = Unit.barricade(power: level.enemyPower)
            barricade.position = CGPoint(x: 0, y: y)
            add(barricade)
        }

        // Pattuglie di guardia.
        let xs: [CGFloat] = [-50, 50, 0, -90, 90, -20]
        for spec in level.patrols {
            for (k, foe) in spec.foes.enumerated() {
                let unit = foe.makeUnit(power: level.enemyPower)
                unit.position = CGPoint(x: xs[k % xs.count],
                                        y: spec.y + CGFloat(k / 3) * 46)
                add(unit)
            }
        }

        // Il Re e la scorta iniziale.
        hero = Unit.hero(hp: config.heroHP, damage: config.heroDamage)
        hero.position = CGPoint(x: 0, y: 80)
        hero.zPosition = 11
        add(hero)
        for x in [CGFloat(-50), CGFloat(50)] {
            let knight = PlayerTroop.cavaliere.makeUnit()
            knight.position = CGPoint(x: x, y: 40)
            add(knight)
        }
    }

    private func add(_ unit: Unit) {
        units.append(unit)
        addChild(unit)
    }

    // MARK: - Input

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        setMoveTarget(touch.location(in: self), showMarker: true)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        setMoveTarget(touch.location(in: self), showMarker: false)
    }

    private func setMoveTarget(_ point: CGPoint, showMarker: Bool) {
        guard !isGameOver else { return }
        let clamped = CGPoint(x: min(max(point.x, -pathHalfWidth + 15), pathHalfWidth - 15),
                              y: min(max(point.y, 40), level.length - 40))
        moveTarget = clamped
        guard showMarker else { return }
        let marker = SKShapeNode(circleOfRadius: 14)
        marker.strokeColor = SKColor(white: 1, alpha: 0.85)
        marker.lineWidth = 2.5
        marker.position = clamped
        marker.zPosition = 5
        addChild(marker)
        marker.run(.sequence([.group([.scale(to: 0.35, duration: 0.35),
                                      .fadeOut(withDuration: 0.35)]),
                              .removeFromParent()]))
    }

    // MARK: - Game loop

    override func update(_ currentTime: TimeInterval) {
        guard !isGameOver else { return }
        let dt: TimeInterval = lastUpdateTime == 0
            ? 1.0 / 60.0
            : min(currentTime - lastUpdateTime, 1.0 / 30.0)
        lastUpdateTime = currentTime
        elapsed += dt

        if elapsed >= level.timeLimit {
            endGame(victory: false)
            return
        }

        // Rigenerazione elisir.
        elixir = min(config.elixirMax, elixir + config.elixirRate * CGFloat(dt))

        // Rinforzi dall'accampamento nemico.
        if level.enemyCampActive {
            spawnAccumulator += dt
            if spawnAccumulator >= level.spawnInterval {
                spawnAccumulator = 0
                spawnRaider()
            }
        }

        // Stati alterati (gelo, veleno).
        for unit in units where unit.isAlive {
            tickStatusEffects(unit, dt: dt)
        }
        if isGameOver { return } // il veleno può uccidere l'eroe

        var troopSlot = 0
        for unit in units where unit.isAlive {
            unit.attackCooldown = max(0, unit.attackCooldown - dt)
            switch unit.team {
            case .enemy:
                updateEnemy(unit, dt: dt)
            case .player:
                if unit === hero {
                    updateFighter(unit, fallback: moveTarget, dt: dt)
                } else {
                    let offset = formationOffsets[troopSlot % formationOffsets.count]
                    troopSlot += 1
                    let formation = CGPoint(x: hero.position.x + offset.x,
                                            y: hero.position.y + offset.y)
                    updateFighter(unit, fallback: formation, dt: dt)
                }
            }
        }

        updateCamera()

        hudAccumulator += dt
        if hudAccumulator >= 0.1 {
            hudAccumulator = 0
            pushHUD()
        }
    }

    private func tickStatusEffects(_ unit: Unit, dt: TimeInterval) {
        if unit.slowRemaining > 0 {
            unit.slowRemaining -= dt
            if unit.slowRemaining <= 0 {
                unit.slowRemaining = 0
                unit.refreshStatusIcon()
            }
        }
        if unit.poisonRemaining > 0 {
            unit.poisonRemaining -= dt
            deal(unit.poisonDPS * CGFloat(dt), to: unit, flash: false)
            if unit.poisonRemaining <= 0 {
                unit.poisonRemaining = 0
                unit.poisonDPS = 0
                unit.refreshStatusIcon()
            }
        }
    }

    private func updateEnemy(_ unit: Unit, dt: TimeInterval) {
        guard unit.damage > 0 else { return } // portone e barricate non attaccano
        guard let target = nearestOpponent(of: unit, within: unit.aggroRange) else { return }
        let d = unit.position.distance(to: target.position)
        if d <= unit.attackRange {
            if unit.attackCooldown == 0 { performAttack(unit, on: target) }
        } else if !unit.isStatic {
            move(unit, toward: target.position, dt: dt)
        }
    }

    private func updateFighter(_ unit: Unit, fallback: CGPoint?, dt: TimeInterval) {
        if unit.traits.healer {
            updateHealer(unit, fallback: fallback, dt: dt)
            return
        }
        if let target = nearestOpponent(of: unit, within: unit.aggroRange) {
            let d = unit.position.distance(to: target.position)
            if d <= unit.attackRange {
                if unit.attackCooldown == 0 { performAttack(unit, on: target) }
            } else {
                move(unit, toward: target.position, dt: dt)
            }
        } else if let dest = fallback, unit.position.distance(to: dest) > 8 {
            move(unit, toward: dest, dt: dt)
        }
    }

    private func updateHealer(_ unit: Unit, fallback: CGPoint?, dt: TimeInterval) {
        let injured = units
            .filter { $0.team == unit.team && $0.isAlive && $0 !== unit && $0.hp < $0.maxHP }
            .min { $0.hp / $0.maxHP < $1.hp / $1.maxHP }
        if let target = injured,
           unit.position.distance(to: target.position) <= unit.aggroRange {
            let d = unit.position.distance(to: target.position)
            if d <= unit.attackRange {
                if unit.attackCooldown == 0 {
                    unit.attackCooldown = unit.attackInterval
                    target.heal(unit.damage)
                    showHealSparkle(at: target.position)
                }
            } else {
                move(unit, toward: target.position, dt: dt)
            }
        } else if let dest = fallback, unit.position.distance(to: dest) > 8 {
            move(unit, toward: dest, dt: dt)
        }
    }

    private func nearestOpponent(of unit: Unit, within range: CGFloat) -> Unit? {
        var best: Unit?
        var bestDistance = CGFloat.greatestFiniteMagnitude
        for other in units where other.isAlive && other.team != unit.team {
            let d = unit.position.distance(to: other.position)
            if d < bestDistance && d <= range {
                bestDistance = d
                best = other
            }
        }
        return best
    }

    private func move(_ unit: Unit, toward point: CGPoint, dt: TimeInterval) {
        let dx = point.x - unit.position.x
        let dy = point.y - unit.position.y
        let len = sqrt(dx * dx + dy * dy)
        guard len > 1 else { return }
        let step = unit.currentSpeed * CGFloat(dt)
        let nx = unit.position.x + dx / len * min(step, len)
        var ny = unit.position.y + dy / len * min(step, len)

        // Le barricate sbarrano la strada alle unità di terra del giocatore.
        if unit.team == .player && !unit.traits.flying {
            for barricade in units
            where barricade.kind == .barricade && barricade.isAlive {
                let limit = barricade.position.y - 36
                if unit.position.y <= limit && ny > limit {
                    ny = limit
                }
            }
        }

        unit.position = CGPoint(x: min(max(nx, -pathHalfWidth + 10), pathHalfWidth - 10),
                                y: min(max(ny, 20), level.length + 20))
    }

    // MARK: - Attacchi

    private func performAttack(_ unit: Unit, on target: Unit) {
        unit.attackCooldown = unit.attackInterval
        let payload = HitPayload(team: unit.team, damage: unit.damage,
                                 damageKind: unit.damageKind, traits: unit.traits)

        if unit.traits.kamikaze {
            showExplosion(at: unit.position, radius: max(70, unit.traits.splashRadius))
            applyHitArea(payload, at: unit.position)
            kill(unit)
            return
        }
        if unit.traits.projectileSpeed > 0 {
            fireProjectile(payload, from: unit, to: target)
        } else {
            unit.lunge(toward: target.position)
            applyHit(payload, to: target)
        }
    }

    private func fireProjectile(_ payload: HitPayload, from unit: Unit, to target: Unit) {
        let projectile = SKShapeNode(circleOfRadius: payload.traits.splashRadius > 0 ? 6 : 5)
        projectile.fillColor = projectileColor(for: payload.traits, team: payload.team)
        projectile.strokeColor = SKColor(white: 0, alpha: 0.4)
        projectile.position = CGPoint(x: unit.position.x, y: unit.position.y + 24)
        projectile.zPosition = 30
        addChild(projectile)

        let destination = target.position
        let duration = TimeInterval(projectile.position.distance(to: destination)
                                    / payload.traits.projectileSpeed)
        projectile.run(.sequence([
            .move(to: destination, duration: duration),
            .run { [weak self, weak target] in
                guard let self else { return }
                if payload.traits.splashRadius > 0 {
                    self.applyHitArea(payload, at: destination)
                } else if let target, target.isAlive,
                          target.position.distance(to: destination) <= 60 {
                    self.applyHit(payload, to: target)
                }
            },
            .removeFromParent(),
        ]))
    }

    private func projectileColor(for traits: CombatTraits, team: Team) -> SKColor {
        if traits.slowFactor > 0 { return SKColor.cyan }
        if traits.poisonDPS > 0 { return SKColor.green }
        return team == .enemy ? SKColor.orange : SKColor.yellow
    }

    /// Moltiplicatore del danno in base a vulnerabilità e resistenze.
    private func damageMultiplier(for kind: DamageKind?, against target: Unit) -> CGFloat {
        guard let kind else { return 1 }
        if target.vulnerabilities.contains(kind) { return 1.5 }
        if target.resistances.contains(kind) { return 0.6 }
        return 1
    }

    private func applyHit(_ payload: HitPayload, to target: Unit) {
        applyEffects(of: payload.traits, to: target)
        let multiplier = damageMultiplier(for: payload.damageKind, against: target)
        let damage = payload.damage * multiplier
        showDamageNumber(damage, multiplier: multiplier, at: target.position)
        deal(damage, to: target)
    }

    private func applyHitArea(_ payload: HitPayload, at point: CGPoint) {
        for other in units where other.isAlive
            && other.team != payload.team
            && other.position.distance(to: point) <= payload.traits.splashRadius {
            applyHit(payload, to: other)
            if isGameOver { return }
        }
    }

    private func applyEffects(of traits: CombatTraits, to target: Unit) {
        var changed = false
        if traits.slowFactor > 0 {
            target.slowFactor = traits.slowFactor
            target.slowRemaining = traits.slowDuration
            changed = true
        }
        if traits.poisonDPS > 0 {
            target.poisonDPS = max(target.poisonDPS, traits.poisonDPS)
            target.poisonRemaining = max(target.poisonRemaining, traits.poisonDuration)
            changed = true
        }
        if changed { target.refreshStatusIcon() }
    }

    private func deal(_ amount: CGFloat, to target: Unit, flash: Bool = true) {
        guard target.applyDamage(amount, flash: flash) else { return }
        // Il bersaglio è morto.
        units.removeAll { $0 === target }
        target.run(.sequence([.group([.fadeOut(withDuration: 0.3),
                                      .scale(to: 0.3, duration: 0.3)]),
                              .removeFromParent()]))
        if target === gate {
            endGame(victory: true)
        } else if target === hero {
            endGame(victory: false)
        }
    }

    /// Elimina immediatamente un'unità (usato dai kamikaze).
    private func kill(_ unit: Unit) {
        deal(unit.maxHP * 100, to: unit, flash: false)
    }

    private func spawnRaider() {
        let raiders = units.filter { $0.team == .enemy && !$0.isStatic }
        guard raiders.count < maxRaiders, gate.isAlive, !level.raiders.isEmpty else { return }
        let foe = level.raiders[raiderIndex % level.raiders.count]
        raiderIndex += 1
        let unit = foe.makeUnit(power: level.enemyPower, aggro: 100_000)
        unit.position = CGPoint(x: CGFloat.random(in: -100...(-40)), y: level.length - 100)
        unit.alpha = 0
        add(unit)
        unit.run(.fadeIn(withDuration: 0.3))
    }

    // MARK: - Spell e evocazioni (chiamate dal ViewModel)

    func castFireball() {
        guard !isGameOver, elapsed >= fireballReadyAt else { return }
        fireballReadyAt = elapsed + fireballCooldown
        let center = hero.position
        showExplosion(at: center, radius: 160)
        let payload = HitPayload(team: .player, damage: config.fireballDamage,
                                 damageKind: .magico,
                                 traits: CombatTraits(splashRadius: 160))
        applyHitArea(payload, at: center)
        pushHUD()
    }

    func castHeal() {
        guard !isGameOver, elapsed >= healReadyAt else { return }
        healReadyAt = elapsed + healCooldown
        for unit in units where unit.team == .player && unit.isAlive {
            unit.heal(unit.maxHP * config.healFraction)
        }
        let pulse = SKShapeNode(circleOfRadius: 90)
        pulse.strokeColor = SKColor(red: 0.3, green: 0.95, blue: 0.4, alpha: 0.9)
        pulse.lineWidth = 5
        pulse.position = hero.position
        pulse.zPosition = 40
        pulse.setScale(0.3)
        addChild(pulse)
        pulse.run(.sequence([.group([.scale(to: 1.3, duration: 0.5),
                                     .fadeOut(withDuration: 0.5)]),
                             .removeFromParent()]))
        pushHUD()
    }

    /// Evoca una squadra della truppa scelta: parte dall'accampamento
    /// e raggiunge il Re. L'unico limite è il costo in elisir.
    func summonTroop(slot: Int) {
        guard !isGameOver, loadout.indices.contains(slot) else { return }
        let troop = loadout[slot]
        guard elixir >= CGFloat(troop.elixirCost) else { return }
        elixir -= CGFloat(troop.elixirCost)
        for _ in 0..<troop.squadSize {
            let unit = troop.makeUnit()
            unit.position = CGPoint(x: campPosition.x + CGFloat.random(in: -50...50),
                                    y: campPosition.y + CGFloat.random(in: -15...15))
            unit.alpha = 0
            add(unit)
            unit.run(.fadeIn(withDuration: 0.25))
        }
        pushHUD()
    }

    // MARK: - Effetti visivi

    private func showExplosion(at point: CGPoint, radius: CGFloat) {
        let blast = SKShapeNode(circleOfRadius: radius)
        blast.fillColor = SKColor(red: 1, green: 0.5, blue: 0.1, alpha: 0.45)
        blast.strokeColor = SKColor(red: 1, green: 0.3, blue: 0, alpha: 0.9)
        blast.lineWidth = 3
        blast.position = point
        blast.zPosition = 40
        blast.setScale(0.2)
        addChild(blast)
        blast.run(.sequence([.group([.scale(to: 1, duration: 0.25),
                                     .fadeOut(withDuration: 0.4)]),
                             .removeFromParent()]))
        let boom = SKLabelNode(text: "💥")
        boom.fontSize = 60
        boom.position = point
        boom.zPosition = 41
        addChild(boom)
        boom.run(.sequence([.wait(forDuration: 0.35),
                            .fadeOut(withDuration: 0.2),
                            .removeFromParent()]))
    }

    private func showHealSparkle(at point: CGPoint) {
        let sparkle = SKLabelNode(text: "✨")
        sparkle.fontSize = 24
        sparkle.position = CGPoint(x: point.x, y: point.y + 20)
        sparkle.zPosition = 40
        addChild(sparkle)
        sparkle.run(.sequence([.group([.moveBy(x: 0, y: 24, duration: 0.5),
                                       .fadeOut(withDuration: 0.5)]),
                               .removeFromParent()]))
    }

    /// Numero di danno fluttuante: arancione se il bersaglio è vulnerabile,
    /// grigio se resistente, bianco se neutro.
    private func showDamageNumber(_ damage: CGFloat, multiplier: CGFloat, at point: CGPoint) {
        let label = SKLabelNode(text: "\(Int(damage.rounded()))")
        label.fontName = "AvenirNext-Heavy"
        label.fontSize = multiplier > 1 ? 17 : 13
        if multiplier > 1 {
            label.fontColor = SKColor.orange
        } else if multiplier < 1 {
            label.fontColor = SKColor(white: 0.75, alpha: 1)
        } else {
            label.fontColor = SKColor.white
        }
        label.position = CGPoint(x: point.x + CGFloat.random(in: -12...12), y: point.y + 26)
        label.zPosition = 45
        addChild(label)
        label.run(.sequence([.group([.moveBy(x: 0, y: 26, duration: 0.6),
                                     .fadeOut(withDuration: 0.6)]),
                             .removeFromParent()]))
    }

    // MARK: - Camera / HUD / fine partita

    private func updateCamera() {
        guard let hero, hero.parent != nil else { return }
        let minY: CGFloat = 380
        let maxY = max(minY, level.length - 260)
        let targetY = min(max(hero.position.y + 150, minY), maxY)
        cam.position = CGPoint(x: 0, y: targetY)
    }

    private func pushHUD() {
        var state = HUDState()
        state.heroHP = hero.maxHP > 0 ? max(0, hero.hp / hero.maxHP) : 0
        state.gateHP = gate.maxHP > 0 ? max(0, gate.hp / gate.maxHP) : 0
        state.timeLeft = max(0, level.timeLimit - elapsed)
        state.allies = units.filter { $0.team == .player && $0 !== hero }.count
        state.elixir = elixir
        state.elixirMax = config.elixirMax
        state.fireballCD = CGFloat(max(0, fireballReadyAt - elapsed) / fireballCooldown)
        state.healCD = CGFloat(max(0, healReadyAt - elapsed) / healCooldown)
        onHUDUpdate?(state)
    }

    private func endGame(victory: Bool) {
        guard !isGameOver else { return }
        isGameOver = true
        pushHUD()
        let banner = SKLabelNode(text: victory ? "🏆" : "💀")
        banner.fontSize = 90
        banner.position = CGPoint(x: cam.position.x, y: cam.position.y + 60)
        banner.zPosition = 100
        banner.setScale(0.2)
        addChild(banner)
        banner.run(.scale(to: 1, duration: 0.35))
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak self] in
            self?.onGameOver?(victory)
        }
    }
}
