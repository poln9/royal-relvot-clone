import SpriteKit

/// Stato sintetico mostrato dall'HUD SwiftUI, aggiornato dalla scena.
struct HUDState {
    var heroHP: CGFloat = 1
    var gateHP: CGFloat = 1
    var timeLeft: TimeInterval = 0
    var allies: Int = 0
    /// Frazione di cooldown residuo (0 = pronto, 1 = appena lanciato).
    var fireballCD: CGFloat = 0
    var healCD: CGFloat = 0
    var summonCD: CGFloat = 0
}

/// Scena principale: il Re avanza lungo il sentiero verticale verso il
/// portone nemico. Tap per muoversi, pulsanti SwiftUI per gli incantesimi.
final class GameScene: SKScene {

    let level: LevelDefinition
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
    private var isGameOver = false

    private var fireballReadyAt: TimeInterval = 0
    private var healReadyAt: TimeInterval = 0
    private var summonReadyAt: TimeInterval = 0
    private let fireballCooldown: TimeInterval = 8
    private let healCooldown: TimeInterval = 15
    private let summonCooldown: TimeInterval = 10

    private let pathHalfWidth: CGFloat = 150
    private let maxAllies = 8
    private let maxRaiders = 12

    private let formationOffsets: [CGPoint] = [
        CGPoint(x: -45, y: -35), CGPoint(x: 45, y: -35),
        CGPoint(x: -70, y: 10),  CGPoint(x: 70, y: 10),
        CGPoint(x: -45, y: -80), CGPoint(x: 45, y: -80),
        CGPoint(x: 0, y: -100),  CGPoint(x: 0, y: 60),
    ]

    init(level: LevelDefinition) {
        self.level = level
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
        for i in 0..<36 {
            let deco = SKLabelNode(text: decoEmoji[i % decoEmoji.count])
            deco.fontSize = CGFloat.random(in: 26...40)
            let side: CGFloat = Bool.random() ? -1 : 1
            deco.position = CGPoint(x: side * CGFloat.random(in: 175...270),
                                    y: CGFloat.random(in: -100...(level.length + 100)))
            deco.zPosition = 2
            addChild(deco)
        }

        // Bandierina di partenza.
        let flag = SKLabelNode(text: "🚩")
        flag.fontSize = 36
        flag.position = CGPoint(x: -60, y: 20)
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

        // Torri difensive, lato alternato.
        for (i, y) in level.towerYs.enumerated() {
            let tower = Unit.tower(power: level.enemyPower)
            let side: CGFloat = i % 2 == 0 ? -1 : 1
            tower.position = CGPoint(x: side * 125, y: y)
            add(tower)
        }

        // Pattuglie di guardia lungo il sentiero.
        for y in level.patrolYs {
            for x in [CGFloat(-45), CGFloat(45)] {
                let goblin = Unit.goblin(power: level.enemyPower)
                goblin.position = CGPoint(x: x, y: y)
                add(goblin)
            }
            if level.includeBrutes {
                let brute = Unit.brute(power: level.enemyPower)
                brute.position = CGPoint(x: 0, y: y + 40)
                add(brute)
            }
        }

        // Il Re e la scorta iniziale.
        hero = Unit.hero()
        hero.position = CGPoint(x: 0, y: 80)
        hero.zPosition = 11
        add(hero)
        for x in [CGFloat(-50), CGFloat(50)] {
            let knight = Unit.knight()
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

        // Rinforzi nemici dal portone.
        spawnAccumulator += dt
        if spawnAccumulator >= level.spawnInterval {
            spawnAccumulator = 0
            spawnRaider()
        }

        var knightSlot = 0
        for unit in units where unit.isAlive {
            unit.attackCooldown = max(0, unit.attackCooldown - dt)
            switch unit.team {
            case .enemy:
                updateEnemy(unit, dt: dt)
            case .player:
                if unit === hero {
                    updateFighter(unit, fallback: moveTarget, dt: dt)
                } else {
                    let slot = knightSlot
                    knightSlot += 1
                    let formation = CGPoint(
                        x: hero.position.x + formationOffsets[slot % formationOffsets.count].x,
                        y: hero.position.y + formationOffsets[slot % formationOffsets.count].y)
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

    private func updateEnemy(_ unit: Unit, dt: TimeInterval) {
        guard unit.damage > 0 else { return } // il portone non attacca
        guard let target = nearestOpponent(of: unit, within: unit.aggroRange) else { return }
        let d = unit.position.distance(to: target.position)
        if d <= unit.attackRange {
            if unit.attackCooldown == 0 { performAttack(unit, on: target) }
        } else if !unit.isStatic {
            move(unit, toward: target.position, dt: dt)
        }
    }

    private func updateFighter(_ unit: Unit, fallback: CGPoint?, dt: TimeInterval) {
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
        let step = unit.moveSpeed * CGFloat(dt)
        let nx = unit.position.x + dx / len * min(step, len)
        let ny = unit.position.y + dy / len * min(step, len)
        unit.position = CGPoint(x: min(max(nx, -pathHalfWidth + 10), pathHalfWidth - 10),
                                y: min(max(ny, 20), level.length + 20))
    }

    private func performAttack(_ unit: Unit, on target: Unit) {
        unit.attackCooldown = unit.attackInterval
        if unit.projectileSpeed > 0 {
            fireProjectile(from: unit, to: target)
        } else {
            unit.lunge(toward: target.position)
            deal(unit.damage, to: target)
        }
    }

    private func fireProjectile(from unit: Unit, to target: Unit) {
        let projectile = SKShapeNode(circleOfRadius: 5)
        projectile.fillColor = .orange
        projectile.strokeColor = SKColor(red: 0.6, green: 0.25, blue: 0, alpha: 1)
        projectile.position = CGPoint(x: unit.position.x, y: unit.position.y + 24)
        projectile.zPosition = 30
        addChild(projectile)

        let destination = target.position
        let duration = TimeInterval(projectile.position.distance(to: destination)
                                    / unit.projectileSpeed)
        let damage = unit.damage
        projectile.run(.sequence([
            .move(to: destination, duration: duration),
            .run { [weak self, weak target] in
                guard let self, let target, target.isAlive else { return }
                if target.position.distance(to: destination) <= 55 {
                    self.deal(damage, to: target)
                }
            },
            .removeFromParent(),
        ]))
    }

    private func deal(_ amount: CGFloat, to target: Unit) {
        guard target.applyDamage(amount) else { return }
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

    private func spawnRaider() {
        let raiders = units.filter { $0.team == .enemy && !$0.isStatic && $0.kind != .gate }
        guard raiders.count < maxRaiders, gate.isAlive else { return }
        let goblin = Unit.goblin(power: level.enemyPower, aggro: 100_000)
        goblin.position = CGPoint(x: CGFloat.random(in: -100...100), y: level.length - 90)
        goblin.alpha = 0
        add(goblin)
        goblin.run(.fadeIn(withDuration: 0.3))
    }

    // MARK: - Incantesimi (chiamati dal ViewModel)

    func castFireball() {
        guard !isGameOver, elapsed >= fireballReadyAt else { return }
        fireballReadyAt = elapsed + fireballCooldown
        let center = hero.position
        showExplosion(at: center, radius: 160)
        for unit in units where unit.team == .enemy
            && unit.isAlive
            && unit.position.distance(to: center) <= 160 {
            deal(90, to: unit)
            if isGameOver { break }
        }
        pushHUD()
    }

    func castHeal() {
        guard !isGameOver, elapsed >= healReadyAt else { return }
        healReadyAt = elapsed + healCooldown
        for unit in units where unit.team == .player && unit.isAlive {
            unit.heal(unit.maxHP * 0.5)
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

    func summonKnights() {
        guard !isGameOver, elapsed >= summonReadyAt else { return }
        let allies = units.filter { $0.team == .player && $0 !== hero }
        guard allies.count < maxAllies else { return }
        summonReadyAt = elapsed + summonCooldown
        for _ in 0..<min(3, maxAllies - allies.count) {
            let knight = Unit.knight()
            knight.position = CGPoint(x: hero.position.x + CGFloat.random(in: -60...60),
                                      y: hero.position.y - CGFloat.random(in: 40...80))
            knight.alpha = 0
            add(knight)
            knight.run(.fadeIn(withDuration: 0.25))
        }
        pushHUD()
    }

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
        state.fireballCD = CGFloat(max(0, fireballReadyAt - elapsed) / fireballCooldown)
        state.healCD = CGFloat(max(0, healReadyAt - elapsed) / healCooldown)
        state.summonCD = CGFloat(max(0, summonReadyAt - elapsed) / summonCooldown)
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
