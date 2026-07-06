# 👑 Royal Relvot

Clone didattico per iOS ispirato alle meccaniche di *Royal Revolt* (tower-defense inverso):
guidi il Re lungo il sentiero, evochi truppe, lanci incantesimi e abbatti il portone
del castello nemico prima che scada il tempo.

**Grafica:** sprite vettoriali **CC0** dal pack
[Medieval RTS](https://kenney.nl/assets/medieval-rts) di **Kenney.nl** (dominio
pubblico), con fallback automatico a emoji. **Audio:** effetti CC0 dai pack
[RPG Audio](https://kenney.nl/assets/rpg-audio),
[Impact Sounds](https://kenney.nl/assets/impact-sounds) e
[Music Jingles](https://kenney.nl/assets/music-jingles) di Kenney;
musiche *"Master of the Feast"* e *"Five Armies"* di **Kevin MacLeod**
(incompetech.com), licenza [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).
Nessun contenuto protetto da copyright del gioco originale.

- **Stack:** Swift 5 · SwiftUI (menu/HUD) · SpriteKit (gameplay)
- **Target:** iPhone (portrait), iOS 17+ — ottimizzato per iPhone 15 Plus (430×932 pt)
- **Dipendenze esterne:** nessuna
- **Contenuti:** 20 livelli · 12 truppe evocabili · 7 nemici · 6 tipi di torre · barricate
- **Sistemi:** elisir (6→20, rigenerazione potenziabile) · oro e potenziamenti
  permanenti · danno per genere (taglio/perforante/esplosivo/magico) con
  vulnerabilità e resistenze · accampamenti (le truppe partono dal tuo,
  il nemico manda rinforzi dal suo dal livello 4)

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

## Come si gioca

- **Muovi il Re** toccando (o trascinando) un punto del sentiero.
- Prima di ogni battaglia scegli **fino a 3 truppe** da portare con te
  (schermata di preparazione esercito); in battaglia ogni truppa ha il suo
  pulsante di evocazione con cooldown. Massimo 12 alleati in campo.
- **Spell:** 🔥 Palla di fuoco ad area intorno al Re (8 s) · 💚 Cura di gruppo
  del 50% (15 s).
- **Obiettivo:** distruggi il portone 🏰 prima dello scadere del timer. Perdi se
  il Re muore o se finisce il tempo.
- Le **barricate** 🪵 sbarrano il sentiero alle unità di terra: abbattile o
  scavalcale con le unità volanti. Le torri di gelo ❄️ rallentano, quelle
  serpe 🐍 avvelenano.
- 20 livelli generati con difficoltà crescente; i progressi restano salvati.

## Truppe del giocatore (12)

| Truppa | Sblocco | Ruolo |
|---|---|---|
| ⚔️ Cavaliere | Liv. 1 | Mischia equilibrato (x3) |
| 🏹 Arciere | Liv. 2 | Tiro rapido a distanza (x3) |
| 🛡️ Paladino | Liv. 3 | Tank da prima linea (x2) |
| 🧙 Piromante | Liv. 4 | Palle di fuoco ad area (x2) |
| ❄️ Gelomante | Liv. 5 | Rallenta i nemici (x2) |
| 🧨 Cannone | Liv. 6 | Danno x2.5 alle strutture (x1) |
| 🧘 Monaco | Liv. 7 | Cura gli alleati (x2) |
| 🎯 Balestriere | Liv. 8 | Colpi precisi e potenti (x2) |
| 💣 Mortaio | Liv. 9 | Bombarda da lontano con splash (x1) |
| 🧌 Ogre | Liv. 10 | Gigante devastante (x1) |
| 🪓 Berserker *(inedito)* | Liv. 12 | Raffica di fendenti velocissima (x2) |
| 🐉 Drago *(inedito)* | Liv. 14 | Vola sopra le barricate, fuoco ad area (x1) |

## Nemici

**Mobili:** 👹 Goblin (liv. 1) · 👺 Bruto (2) · 🐺 Lupo Mannaro (3) ·
🦹 Tiratore Oscuro (4) · 🧟 Mummia (7) · 🦇 Gargolla kamikaze (10) ·
🧛 Negromante (13)

**Torri** (badge sopra la torre ne indica il tipo): 🏹 Freccia (1) ·
💣 Bomba con splash (3) · ❄️ Gelo che rallenta (5) · 🐍 Serpe che avvelena (8) ·
🔥 Fuoco a lunga gittata (11) · 💀 Teschio con splash pesante (15)

**Strutture:** 🪵 Barricate (dal liv. 4) · 🏰 Portone (obiettivo)

## Architettura

```
RoyalRelvot/
├── RoyalRelvotApp.swift   // entry point SwiftUI
├── ContentView.swift      // menu, loadout, HUD, overlay vittoria/sconfitta
├── GameViewModel.swift    // navigazione + ponte SwiftUI ↔ SpriteKit
├── GameScene.swift        // game loop: movimento, combattimento, spell, camera
├── Entities.swift         // classe Unit + tratti di combattimento
├── Roster.swift           // truppe giocatore, nemici e torri (dati + factory)
└── Levels.swift           // generatore deterministico dei 20 livelli
```

Scelte principali:

- **Una sola classe `Unit`** per tutte le entità; i comportamenti speciali
  (splash, gelo, veleno, kamikaze, curatore, volante, anti-strutture) sono
  descritti da `CombatTraits`, così il sistema di combattimento resta unico.
- **Livelli procedurali deterministici**: `Levels.swift` genera i 20 livelli con
  un PRNG seedato (identici a ogni avvio), introducendo nuovi nemici e torri
  man mano che si avanza.
- **La scena è la fonte di verità** (HP, cooldown, timer) e pubblica uno `HUDState`
  ~10 volte al secondo verso SwiftUI; i pulsanti chiamano metodi della scena.
- **Progetto Xcode 16 con cartella sincronizzata**: ogni file aggiunto in
  `RoyalRelvot/` entra automaticamente nel target, senza toccare il `.pbxproj`.

## Bilanciamento rapido

- `Roster.swift` → statistiche, sblocchi, dimensione squadra e cooldown di ogni
  truppa/nemico/torre.
- `Levels.swift` → curve di difficoltà (lunghezza, numero torri/pattuglie,
  HP portone, timer, potenza nemici, barricate).
- `Entities.swift` → eroe, portone, barricate e meccaniche dei tratti.
