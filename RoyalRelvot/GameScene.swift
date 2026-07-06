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

/// Scena principale. Il mondo è un insieme di corridoi (curve e
/// biforcazioni); le truppe evocate partono dall'accampamento e seguono
/// da sole la strada verso il portone, l'eroe è comandato dal giocatore
/// e non insegue mai: attacca ciò che gli capita a tiro.
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

    /// Limite tecnico ai nemici in campo (per le prestazioni).
    private let maxRaiders = 18
    /// Oltre questa distanza i nemici smettono di inseguire e tornano
    /// alla loro routine (pattuglia ferma o marcia lungo la strada).
    private let engagementRange: CGFloat = 320

    private var campPosition: CGPoint { level.road[0] }

    // Effetti sonori: azioni precaricate e throttling per non
    // sovrapporre decine di suoni identici nello stesso istante.
    private var soundActions: [String: SKAction] = [:]
    private var lastSoundAt: [String: TimeInterval] = [:]

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
        // Verde prato della palette Kenney Medieval RTS.
        backgroundColor = SKColor(red: 39 / 255, green: 174 / 255, blue: 96 / 255, alpha: 1)
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
        buildTerrain()
        buildScenery()

        // Accampamento del giocatore: da qui partono le truppe evocate.
        let camp = decoNode(sprite: "camp_player", emoji: "⛺", size: 46)
        camp.position = CGPoint(x: campPosition.x - 58, y: campPosition.y - 20)
        camp.zPosition = 2
        addChild(camp)
        let campfire = decoNode(sprite: "deco_fire", emoji: "🔥", size: 22)
        campfire.position = CGPoint(x: campPosition.x + 62, y: campPosition.y - 15)
        campfire.zPosition = 2
        campfire.run(.repeatForever(.sequence([.scale(to: 1.15, duration: 0.35),
                                               .scale(to: 0.95, duration: 0.35)])))
        addChild(campfire)

        // Portone nemico e mura in cima.
        let gatePos = level.gatePosition
        gate = Unit.gate(hp: level.gateHP)
        gate.position = gatePos
        add(gate)
        for side: CGFloat in [-1, 1] {
            let wall = decoNode(sprite: "gatewall", emoji: "", size: 74)
            wall.position = CGPoint(x: gatePos.x + side * 155, y: gatePos.y + 4)
            wall.zPosition = 3
            addChild(wall)
        }

        // Accampamento nemico (attivo dal livello 4: invia truppe regolarmente).
        if level.enemyCampActive {
            let enemyCamp = decoNode(sprite: "camp_enemy", emoji: "⛺", size: 48)
            enemyCamp.position = CGPoint(x: gatePos.x - 66, y: gatePos.y - 100)
            enemyCamp.zPosition = 2
            addChild(enemyCamp)
            let fire = decoNode(sprite: "deco_fire", emoji: "🔥", size: 20)
            fire.position = CGPoint(x: gatePos.x - 20, y: gatePos.y - 118)
            fire.zPosition = 2
            fire.run(.repeatForever(.sequence([.scale(to: 1.15, duration: 0.4),
                                               .scale(to: 0.95, duration: 0.4)])))
            addChild(fire)
        }

        // Torri difensive.
        for spec in level.towers {
            let tower = spec.kind.makeUnit(power: level.enemyPower)
            tower.position = spec.position
            add(tower)
        }

        // Barricate sui tratti verticali della strada.
        for point in level.barricadePoints {
            let barricade = Unit.barricade(power: level.enemyPower)
            barricade.position = point
            add(barricade)
        }

        // Pattuglie di guardia.
        let offsets: [CGPoint] = [CGPoint(x: -45, y: 0), CGPoint(x: 45, y: 0),
                                  CGPoint(x: 0, y: 42), CGPoint(x: -55, y: 46),
                                  CGPoint(x: 55, y: 46), CGPoint(x: 0, y: -40)]
        for spec in level.patrols {
            for (k, foe) in spec.foes.enumerated() {
                let unit = foe.makeUnit(power: level.enemyPower)
                let off = offsets[k % offsets.count]
                unit.position = CGPoint(x: spec.position.x + off.x,
                                        y: spec.position.y + off.y)
                add(unit)
            }
        }

        // Il Re e la scorta iniziale.
        hero = Unit.hero(hp: config.heroHP, damage: config.heroDamage)
        hero.position = CGPoint(x: campPosition.x, y: campPosition.y + 45)
        hero.zPosition = 11
        add(hero)
        for x in [CGFloat(-45), CGFloat(45)] {
            let knight = PlayerTroop.cavaliere.makeUnit()
            knight.position = CGPoint(x: campPosition.x + x, y: campPosition.y)
            add(knight)
        }
    }

    private func add(_ unit: Unit) {
        units.append(unit)
        addChild(unit)
    }

    /// Nodo decorativo: sprite se disponibile nel bundle, altrimenti emoji.
    private func decoNode(sprite: String, emoji: String, size: CGFloat) -> SKNode {
        if UIImage(named: sprite) != nil {
            let texture = SKTexture(imageNamed: sprite)
            let node = SKSpriteNode(texture: texture)
            let maxSide = max(texture.size().width, texture.size().height)
            if maxSide > 0 { node.setScale(size * 1.5 / maxSide) }
            return node
        }
        let label = SKLabelNode(text: emoji)
        label.fontSize = size
        return label
    }

    /// Riempie i corridoi con tile di terra battuta (ritagliate al bordo);
    /// se le texture mancano usa un colore pieno.
    private func buildTerrain() {
        let dirtColor = SKColor(red: 187 / 255, green: 128 / 255, blue: 68 / 255, alpha: 1)
        let hasTiles = UIImage(named: "tile_dirt1") != nil && UIImage(named: "tile_dirt2") != nil

        for rect in level.corridors {
            guard hasTiles else {
                let node = SKSpriteNode(color: dirtColor, size: rect.size)
                node.position = CGPoint(x: rect.midX, y: rect.midY)
                node.zPosition = 1
                addChild(node)
                continue
            }
            let crop = SKCropNode()
            crop.position = CGPoint(x: rect.midX, y: rect.midY)
            crop.maskNode = SKSpriteNode(color: .white, size: rect.size)
            crop.zPosition = 1
            let tileSize: CGFloat = 70
            let cols = Int(ceil(rect.width / tileSize))
            let rows = Int(ceil(rect.height / tileSize))
            for r in 0..<rows {
                for c in 0..<cols {
                    let texture = SKTexture(imageNamed: (r + c) % 2 == 0 ? "tile_dirt1" : "tile_dirt2")
                    let tile = SKSpriteNode(texture: texture)
                    tile.size = CGSize(width: tileSize, height: tileSize)
                    tile.position = CGPoint(x: -rect.width / 2 + (CGFloat(c) + 0.5) * tileSize,
                                            y: -rect.height / 2 + (CGFloat(r) + 0.5) * tileSize)
                    crop.addChild(tile)
                }
            }
            addChild(crop)
        }
    }

    /// Punto casuale sull'erba, ad almeno `margin` punti dai corridoi.
    private func randomGrassPoint(margin: CGFloat, attempts: Int = 30) -> CGPoint? {
        for _ in 0..<attempts {
            let p = CGPoint(x: CGFloat.random(in: -300...300),
                            y: CGFloat.random(in: -120...(level.length + 80)))
            // Margine negativo = corridoio espanso: il punto deve restarne fuori.
            if !isWalkable(p, margin: -margin) { return p }
        }
        return nil
    }

    /// Arricchisce l'erba: laghetti, boschi, villaggi con fattorie,
    /// alberi, cespugli, rocce.
    private func buildScenery() {
        // Laghetti (ellissi color acqua della palette).
        for _ in 0..<(3 + Int(level.length / 1400)) {
            guard let p = randomGrassPoint(margin: 85) else { continue }
            let w = CGFloat.random(in: 90...160)
            let h = w * CGFloat.random(in: 0.55...0.75)
            let pond = SKShapeNode(ellipseOf: CGSize(width: w, height: h))
            pond.fillColor = SKColor(red: 176 / 255, green: 233 / 255, blue: 252 / 255, alpha: 1)
            pond.strokeColor = SKColor(white: 1, alpha: 0.75)
            pond.lineWidth = 4
            pond.position = p
            pond.zPosition = 0.5
            addChild(pond)
        }

        // Macchie di bosco e cespugli (tile con fondo erba).
        let patchNames = ["tile_forest1", "tile_forest2", "tile_forest3", "tile_bushes"]
        for _ in 0..<(5 + Int(level.length / 900)) {
            guard let p = randomGrassPoint(margin: 90) else { continue }
            let patch = decoNode(sprite: patchNames[Int.random(in: 0..<patchNames.count)],
                                 emoji: "🌲", size: CGFloat.random(in: 70...110))
            patch.position = p
            patch.zPosition = 0.6
            addChild(patch)
        }

        // Villaggi: casa + campo coltivato + fienile o mercato.
        let houseNames = ["deco_house1", "deco_house2", "deco_house3", "deco_house4"]
        let farmNames = ["tile_farm1", "tile_farm2", "tile_farm3", "tile_farm4"]
        for v in 0..<(2 + Int(level.length / 2200)) {
            guard let p = randomGrassPoint(margin: 110) else { continue }
            let house = decoNode(sprite: houseNames[v % houseNames.count],
                                 emoji: "🏠", size: 52)
            house.position = p
            house.zPosition = 2
            addChild(house)
            let farm = decoNode(sprite: farmNames[v % farmNames.count],
                                emoji: "🌾", size: 56)
            farm.position = CGPoint(x: p.x + CGFloat.random(in: -70 ... -50),
                                    y: p.y + CGFloat.random(in: -20...20))
            farm.zPosition = 0.8
            addChild(farm)
            let extra = decoNode(sprite: v % 2 == 0 ? "deco_barn" : "deco_market",
                                 emoji: "🏚️", size: 44)
            extra.position = CGPoint(x: p.x + CGFloat.random(in: 48...66),
                                     y: p.y + CGFloat.random(in: -26...26))
            extra.zPosition = 2
            addChild(extra)
        }

        // Vegetazione e rocce sparse.
        let decoSprites = ["deco_tree1", "deco_tree2", "deco_tree3", "deco_tree4",
                           "deco_bush1", "deco_bush2", "deco_stump",
                           "deco_rock1", "deco_rock2", "deco_rock3"]
        let decoEmoji = ["🌳", "🌳", "🌲", "🌲", "🌿", "🌿", "🪵", "🪨", "🪨", "🪨"]
        for _ in 0..<80 {
            guard let p = randomGrassPoint(margin: 26, attempts: 6) else { continue }
            let pick = Int.random(in: 0..<decoSprites.count)
            let deco = decoNode(sprite: decoSprites[pick], emoji: decoEmoji[pick],
                                size: pick < 4 ? CGFloat.random(in: 30...48)
                                               : CGFloat.random(in: 20...32))
            deco.position = p
            deco.zPosition = 2
            addChild(deco)
        }
    }

    // MARK: - Terreno percorribile

    private func isWalkable(_ point: CGPoint, margin: CGFloat = -8) -> Bool {
        for rect in level.corridors where rect.insetBy(dx: margin, dy: margin).contains(point) {
            return true
        }
        return false
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
        let clamped = CGPoint(x: min(max(point.x, -290), 290),
                              y: min(max(point.y, 20), level.length - 30))
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

        for unit in units where unit.isAlive {
            unit.attackCooldown = max(0, unit.attackCooldown - dt)
            switch unit.team {
            case .enemy:
                updateEnemy(unit, dt: dt)
            case .player:
                if unit === hero {
                    updateHero(dt: dt)
                } else {
                    updateAlly(unit, dt: dt)
                }
            }
        }

        // Animazione camminata: attiva solo per chi si è mosso di recente.
        for unit in units where unit.isAlive && !unit.isStatic {
            unit.setWalking(elapsed - unit.lastWalkAt < 0.15)
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

    // MARK: - Comportamenti

    /// L'eroe obbedisce solo al giocatore: si muove verso il punto toccato
    /// e attacca senza fermarsi ciò che entra nel suo raggio. Mai inseguire:
    /// così può sempre disimpegnarsi da un corpo a corpo.
    private func updateHero(dt: TimeInterval) {
        if hero.attackCooldown == 0,
           let target = nearestOpponent(of: hero, within: hero.attackRange) {
            performAttack(hero, on: target)
        }
        if let dest = moveTarget, hero.position.distance(to: dest) > 8 {
            move(hero, toward: dest, dt: dt)
        }
    }

    /// Le truppe alleate avanzano da sole lungo la strada verso il portone,
    /// ingaggiando ciò che incontrano.
    private func updateAlly(_ unit: Unit, dt: TimeInterval) {
        if unit.traits.healer {
            updateHealer(unit, dt: dt)
            return
        }
        if let target = nearestOpponent(of: unit, within: unit.aggroRange) {
            let d = unit.position.distance(to: target.position)
            if d <= unit.attackRange {
                if unit.attackCooldown == 0 { performAttack(unit, on: target) }
            } else {
                move(unit, toward: target.position, dt: dt)
            }
        } else {
            move(unit, toward: roadTarget(for: unit, ascending: true), dt: dt)
        }
    }

    private func updateHealer(_ unit: Unit, dt: TimeInterval) {
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
        } else {
            move(unit, toward: roadTarget(for: unit, ascending: true), dt: dt)
        }
    }

    private func updateEnemy(_ unit: Unit, dt: TimeInterval) {
        guard unit.damage > 0 else { return } // portone e barricate non attaccano
        let isRaider = unit.aggroRange >= 9000
        let range = min(unit.aggroRange, engagementRange)
        if let target = nearestOpponent(of: unit, within: range) {
            let d = unit.position.distance(to: target.position)
            if d <= unit.attackRange {
                if unit.attackCooldown == 0 { performAttack(unit, on: target) }
            } else if !unit.isStatic {
                move(unit, toward: target.position, dt: dt)
            }
        } else if isRaider && !unit.isStatic {
            // I rinforzi marciano lungo la strada verso il campo del giocatore.
            move(unit, toward: roadTarget(for: unit, ascending: false), dt: dt)
        }
    }

    /// Prossimo waypoint della strada per un'unità che avanza (ascending)
    /// o scende verso il campo del giocatore (descending).
    private func roadTarget(for unit: Unit, ascending: Bool) -> CGPoint {
        let road = level.road
        // Riaggancia il waypoint più vicino se mai inizializzato o troppo lontano.
        if unit.roadIndex < 0 || unit.roadIndex >= road.count
            || unit.position.distance(to: road[unit.roadIndex]) > 340 {
            var best = 0
            var bestDistance = CGFloat.greatestFiniteMagnitude
            for (k, p) in road.enumerated() {
                let d = unit.position.distance(to: p)
                if d < bestDistance { bestDistance = d; best = k }
            }
            unit.roadIndex = best
        }
        let next = ascending ? min(unit.roadIndex + 1, road.count - 1)
                             : max(unit.roadIndex - 1, 0)
        if unit.position.distance(to: road[next]) < 36 {
            unit.roadIndex = next
        }
        return road[next]
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

    /// Movimento con scorrimento lungo i muri: se la posizione tentata esce
    /// dai corridoi prova prima solo l'asse Y, poi solo l'asse X.
    private func move(_ unit: Unit, toward point: CGPoint, dt: TimeInterval) {
        let dx = point.x - unit.position.x
        let dy = point.y - unit.position.y
        let len = sqrt(dx * dx + dy * dy)
        guard len > 1 else { return }
        let step = unit.currentSpeed * CGFloat(dt)
        let nx = unit.position.x + dx / len * min(step, len)
        var ny = unit.position.y + dy / len * min(step, len)

        // Le barricate sbarrano la strada alle unità di terra del giocatore
        // (solo nella loro corsia).
        if unit.team == .player && !unit.traits.flying {
            for barricade in units
            where barricade.kind == .barricade && barricade.isAlive
                && abs(unit.position.x - barricade.position.x) < 85 {
                let limit = barricade.position.y - 36
                if unit.position.y <= limit && ny > limit {
                    ny = limit
                }
            }
        }

        let clampedX = min(max(nx, -300), 300)
        let clampedY = min(max(ny, 0), level.length + 30)
        let attempted = CGPoint(x: clampedX, y: clampedY)

        if unit.traits.flying || isWalkable(attempted) {
            unit.position = attempted
        } else if isWalkable(CGPoint(x: unit.position.x, y: clampedY)) {
            unit.position = CGPoint(x: unit.position.x, y: clampedY)
        } else if isWalkable(CGPoint(x: clampedX, y: unit.position.y)) {
            unit.position = CGPoint(x: clampedX, y: unit.position.y)
        } else {
            return
        }
        unit.lastWalkAt = elapsed
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
            switch unit.damageKind {
            case .perforante: playSound("sfx_arrow")
            case .magico: playSound("sfx_magic")
            default: break
            }
            fireProjectile(payload, from: unit, to: target)
        } else {
            unit.lunge(toward: target.position)
            playSound("sfx_melee")
            applyHit(payload, to: target)
        }
    }

    /// Ogni genere di attacco a distanza ha il suo proiettile:
    /// freccia ruotata, bomba, cristallo di gelo, fiala di veleno,
    /// globo di fuoco o di magia oscura.
    private func makeProjectileNode(for payload: HitPayload, angle: CGFloat) -> SKNode {
        let traits = payload.traits
        if traits.slowFactor > 0 {
            // Cristallo di gelo: rombo ciano.
            let diamond = SKShapeNode(rectOf: CGSize(width: 11, height: 11))
            diamond.fillColor = .cyan
            diamond.strokeColor = SKColor(white: 1, alpha: 0.8)
            diamond.zRotation = .pi / 4
            return diamond
        }
        if traits.poisonDPS > 0 {
            // Fiala di veleno: goccia verde.
            let drop = SKShapeNode(circleOfRadius: 6)
            drop.fillColor = SKColor(red: 0.35, green: 0.85, blue: 0.2, alpha: 1)
            drop.strokeColor = SKColor(red: 0.1, green: 0.4, blue: 0.05, alpha: 1)
            return drop
        }
        switch payload.damageKind {
        case .perforante:
            // Freccia (sprite Kenney orientata a 45°) ruotata verso il bersaglio.
            if UIImage(named: "proj_arrow") != nil {
                let texture = SKTexture(imageNamed: "proj_arrow")
                texture.filteringMode = .nearest
                let arrow = SKSpriteNode(texture: texture)
                arrow.setScale(28 / max(texture.size().width, texture.size().height))
                arrow.zRotation = angle - .pi / 4
                return arrow
            }
            let bolt = SKShapeNode(rectOf: CGSize(width: 16, height: 3), cornerRadius: 1.5)
            bolt.fillColor = SKColor(red: 0.55, green: 0.38, blue: 0.2, alpha: 1)
            bolt.strokeColor = .clear
            bolt.zRotation = angle
            return bolt
        case .esplosivo:
            // Bomba (sprite Kenney) o palla di cannone.
            if UIImage(named: "proj_bomb") != nil {
                let texture = SKTexture(imageNamed: "proj_bomb")
                texture.filteringMode = .nearest
                let bomb = SKSpriteNode(texture: texture)
                bomb.setScale(24 / max(texture.size().width, texture.size().height))
                return bomb
            }
            let ball = SKShapeNode(circleOfRadius: 7)
            ball.fillColor = SKColor(white: 0.2, alpha: 1)
            ball.strokeColor = SKColor(white: 0.05, alpha: 1)
            return ball
        case .magico:
            // Globo magico: fuoco per il giocatore, magia oscura per i nemici.
            let orb = SKShapeNode(circleOfRadius: 7)
            if payload.team == .enemy {
                orb.fillColor = SKColor(red: 0.65, green: 0.3, blue: 0.9, alpha: 0.95)
                orb.strokeColor = SKColor(red: 0.4, green: 0.1, blue: 0.6, alpha: 1)
            } else {
                orb.fillColor = SKColor(red: 1, green: 0.55, blue: 0.15, alpha: 0.95)
                orb.strokeColor = SKColor(red: 0.8, green: 0.25, blue: 0, alpha: 1)
            }
            orb.glowWidth = 3
            return orb
        default:
            let dot = SKShapeNode(circleOfRadius: 5)
            dot.fillColor = payload.team == .enemy ? .orange : .yellow
            dot.strokeColor = SKColor(white: 0, alpha: 0.4)
            return dot
        }
    }

    private func fireProjectile(_ payload: HitPayload, from unit: Unit, to target: Unit) {
        let origin = CGPoint(x: unit.position.x, y: unit.position.y + 24)
        let destination = target.position
        let angle = atan2(destination.y - origin.y, destination.x - origin.x)

        let projectile = makeProjectileNode(for: payload, angle: angle)
        projectile.position = origin
        projectile.zPosition = 30
        addChild(projectile)

        let duration = TimeInterval(origin.distance(to: destination)
                                    / payload.traits.projectileSpeed)
        projectile.run(.sequence([
            .move(to: destination, duration: duration),
            .run { [weak self, weak target] in
                guard let self else { return }
                if payload.traits.splashRadius > 0 {
                    self.showExplosion(at: destination,
                                       radius: payload.traits.splashRadius)
                    self.applyHitArea(payload, at: destination)
                } else if let target, target.isAlive,
                          target.position.distance(to: destination) <= 60 {
                    self.applyHit(payload, to: target)
                }
            },
            .removeFromParent(),
        ]))
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
        playSound(target.isStatic ? "sfx_structure" : "sfx_death", throttle: 0.12)
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
        let gatePos = level.gatePosition
        unit.position = CGPoint(x: gatePos.x + CGFloat.random(in: -60...60),
                                y: gatePos.y - 110)
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
        playSound("sfx_heal")
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
    /// e avanza da sola. L'unico limite è il costo in elisir.
    func summonTroop(slot: Int) {
        guard !isGameOver, loadout.indices.contains(slot) else { return }
        let troop = loadout[slot]
        guard elixir >= CGFloat(troop.elixirCost) else { return }
        elixir -= CGFloat(troop.elixirCost)
        playSound("sfx_summon")
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

    // MARK: - Suoni

    private func playSound(_ name: String, throttle: TimeInterval = 0.09) {
        if let last = lastSoundAt[name], elapsed - last < throttle { return }
        if soundActions[name] == nil {
            guard Bundle.main.url(forResource: name, withExtension: "wav") != nil else { return }
            soundActions[name] = SKAction.playSoundFileNamed("\(name).wav",
                                                             waitForCompletion: false)
        }
        guard let action = soundActions[name] else { return }
        lastSoundAt[name] = elapsed
        run(action)
    }

    // MARK: - Effetti visivi

    private func showExplosion(at point: CGPoint, radius: CGFloat) {
        playSound("sfx_explosion", throttle: 0.15)
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
        boom.fontSize = min(60, radius * 0.7)
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
        // Segue l'eroe anche in orizzontale (il mondo è più largo dello schermo).
        let targetX = min(max(hero.position.x, -90), 90)
        cam.position = CGPoint(x: targetX, y: targetY)
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
