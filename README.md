# 👑 Royal Relvot

Clone didattico per iOS ispirato alle meccaniche di *Royal Revolt* (tower-defense inverso):
guidi il Re lungo il sentiero, evochi cavalieri, lanci incantesimi e abbatti il portone
del castello nemico prima che scada il tempo.

Tutti gli asset sono originali (emoji + grafica procedurale): nessun contenuto
protetto da copyright del gioco originale.

- **Stack:** Swift 5 · SwiftUI (menu/HUD) · SpriteKit (gameplay)
- **Target:** iPhone (portrait), iOS 17+ — ottimizzato per iPhone 15 Plus (430×932 pt)
- **Dipendenze esterne:** nessuna

## Come eseguirlo su iPhone 15 Plus

Le app iOS si compilano solo con **Xcode su macOS** (requisito Apple — da Windows non è
possibile). Servono un Mac con **Xcode 16+** e un account Apple (va bene quello gratuito).

1. Copia questa cartella sul Mac e apri `RoyalRelvot.xcodeproj`.
2. Seleziona il target **RoyalRelvot** → tab *Signing & Capabilities* → scegli il tuo
   **Team** (Xcode sistema il provisioning in automatico; se il bundle id risulta
   occupato, cambia `com.nicola.RoyalRelvot` in uno tuo).
3. Collega l'iPhone 15 Plus via cavo (o Wi-Fi) e selezionalo come destinazione di run.
4. Sull'iPhone abilita la **Modalità Sviluppatore**: *Impostazioni → Privacy e
   sicurezza → Modalità sviluppatore* (il telefono si riavvia).
5. Premi **⌘R**. Al primo avvio autorizza il certificato in *Impostazioni → Generali →
   VPN e gestione dispositivi*.

In alternativa funziona identico nel **simulatore iPhone 15 Plus** (nessuna firma richiesta).

### Senza Mac: build su GitHub Actions + sideload da Windows

Il repo include una pipeline ([.github/workflows/ios-build.yml](.github/workflows/ios-build.yml))
che compila l'app su un runner macOS e produce una **.ipa non firmata**:

1. Crea un repository su GitHub e pusha questa cartella (`git init`, commit, push).
2. Su GitHub → tab **Actions** → workflow "iOS build" → al termine scarica
   l'artifact **RoyalRelvot-ipa**.
3. Su Windows installa [Sideloadly](https://sideloadly.io/), collega l'iPhone via USB,
   trascina la `.ipa`, inserisci il tuo Apple ID e premi *Start*: Sideloadly firma
   e installa l'app.
4. Sull'iPhone autorizza il profilo in *Impostazioni → Generali → VPN e gestione
   dispositivi*, poi abilita la Modalità sviluppatore se richiesta.

Limiti dell'Apple ID gratuito: l'app scade dopo **7 giorni** (basta rifare il
sideload) e massimo 3 app installate così. Con l'account Developer ($99/anno)
la firma dura un anno.

## Comandi di gioco

| Azione | Comando |
|---|---|
| Muovere il Re | Tocca (o trascina) un punto del sentiero |
| 🔥 Palla di fuoco | Danno ad area intorno al Re (cooldown 8 s) |
| 💚 Cura | Cura Re e cavalieri del 50% (cooldown 15 s) |
| 🛡️ Evoca | 3 cavalieri di scorta, max 8 (cooldown 10 s) |

**Obiettivo:** distruggi il portone 🏰 prima dello scadere del timer. Perdi se il Re
muore o se finisce il tempo. Le torri 🗼 sparano dalla distanza, le pattuglie 👹/👺
difendono il sentiero e il portone manda rinforzi continui. 3 livelli a difficoltà
crescente; i progressi si sbloccano e restano salvati (`UserDefaults`).

## Architettura

```
RoyalRelvot/
├── RoyalRelvotApp.swift   // entry point SwiftUI
├── ContentView.swift      // menu, HUD, overlay vittoria/sconfitta
├── GameViewModel.swift    // navigazione + ponte SwiftUI ↔ SpriteKit
├── GameScene.swift        // game loop: movimento, combattimento, spell, camera
├── Entities.swift         // classe Unit unificata (eroe, truppe, torri, portone)
└── Levels.swift           // definizione dati dei 3 livelli
```

Scelte principali:

- **Una sola classe `Unit`** per tutte le entità: le strutture (torri, portone) sono
  unità con `moveSpeed == 0`, così un unico sistema di combattimento gestisce tutto.
- **La scena è la fonte di verità** (HP, cooldown, timer) e pubblica uno `HUDState`
  ~10 volte al secondo verso SwiftUI; i pulsanti spell chiamano metodi della scena.
- **Progetto Xcode 16 con cartella sincronizzata**: ogni file aggiunto in
  `RoyalRelvot/` entra automaticamente nel target, senza toccare il `.pbxproj`.

## Bilanciamento rapido

Vuoi ritoccare la difficoltà? Tutto in due file:

- `Levels.swift` → lunghezza sentiero, numero torri/pattuglie, HP portone, timer,
  `enemyPower` (moltiplicatore HP/danno nemici).
- `Entities.swift` → statistiche di ogni unità nelle factory (`hero()`, `knight()`, …).
