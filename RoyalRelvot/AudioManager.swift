import AVFoundation

/// Musica di sottofondo e jingle di fine partita.
/// Gli effetti di gioco vivono nella scena SpriteKit (SKAction);
/// qui c'è solo ciò che deve sopravvivere al cambio di scena.
final class AudioManager {
    static let shared = AudioManager()

    private var musicPlayer: AVAudioPlayer?
    private var jinglePlayer: AVAudioPlayer?
    private var currentTrack: String?

    private init() {
        // .ambient: la musica di altre app non viene interrotta e
        // l'interruttore silenzioso viene rispettato.
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    func playMusic(_ name: String) {
        guard currentTrack != name else { return }
        guard let url = Bundle.main.url(forResource: name, withExtension: "mp3") else { return }
        currentTrack = name
        musicPlayer?.stop()
        musicPlayer = try? AVAudioPlayer(contentsOf: url)
        musicPlayer?.numberOfLoops = -1
        musicPlayer?.volume = 0.35
        musicPlayer?.play()
    }

    func stopMusic() {
        musicPlayer?.stop()
        currentTrack = nil
    }

    func playJingle(_ name: String) {
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav") else { return }
        jinglePlayer = try? AVAudioPlayer(contentsOf: url)
        jinglePlayer?.volume = 0.6
        jinglePlayer?.play()
    }
}
