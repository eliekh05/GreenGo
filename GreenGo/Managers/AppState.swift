import SwiftUI
import AVFoundation
import AudioToolbox

@MainActor
final class SoundFXManager {
    static let shared = SoundFXManager()

    private var touchPlayer: AVAudioPlayer?
    private var dingPlayer: AVAudioPlayer?
    private var buzzerPlayer: AVAudioPlayer?

    private init() {
        touchPlayer = loadPlayer(named: "Touch", ext: "mp4")
        dingPlayer = loadPlayer(named: "Ding", ext: "mp4")
        buzzerPlayer = loadPlayer(named: "Buzzer", ext: "mp4")
    }

    func playTouch(vibrate: Bool = true) {
        play(touchPlayer)
        if vibrate { lightVibrate() }
    }

    func playDing(vibrate: Bool = false) {
        play(dingPlayer)
        if vibrate { lightVibrate() }
    }

    func playBuzzer(vibrate: Bool = true) {
        play(buzzerPlayer)
        if vibrate { heavyVibrate() }
    }

    private func play(_ player: AVAudioPlayer?) {
        guard let player else { return }
        if player.isPlaying { player.currentTime = 0 }
        player.play()
    }

    private func loadPlayer(named name: String, ext: String) -> AVAudioPlayer? {
        guard let url = Bundle.main.url(forResource: name, withExtension: ext) else { return nil }
        let player = try? AVAudioPlayer(contentsOf: url)
        player?.prepareToPlay()
        return player
    }

    private func lightVibrate() {
        AudioServicesPlaySystemSound(1519)
    }

    private func heavyVibrate() {
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
    }
}

@MainActor
final class AppState: ObservableObject {

    // MARK: - Navigation
    @Published var screen: Screen = .splash {
        didSet {
            guard oldValue != screen else { return }
            // AIA plays touch feedback on most navigation clicks.
            if oldValue != .splash {
                SoundFXManager.shared.playTouch()
            }
        }
    }

    // MARK: - Scores (persisted)
    @Published var triviaScore: Int    = UserDefaults.standard.integer(forKey: "score_trivia")
    @Published var memoryScore: Int    = UserDefaults.standard.integer(forKey: "score_memory")
    @Published var oceanScore:  Int    = UserDefaults.standard.integer(forKey: "score_ocean")

    // MARK: - "Don't show again" flags
    @Published var skipMapInfo:    Bool = UserDefaults.standard.bool(forKey: "skip_mapInfo")
    @Published var skipOceanInfo:  Bool = UserDefaults.standard.bool(forKey: "skip_oceanInfo")
    @Published var skipMemoryInfo: Bool = UserDefaults.standard.bool(forKey: "skip_memoryInfo")

    // MARK: - Theme
    @Published var theme: AppTheme = {
        let raw = UserDefaults.standard.string(forKey: "appTheme") ?? "mint"
        return AppTheme(rawValue: raw) ?? .mint
    }()

    // MARK: Score helpers
    func saveTriviaScore(_ v: Int) {
        triviaScore = max(triviaScore, v)
        UserDefaults.standard.set(triviaScore, forKey: "score_trivia")
    }
    func saveMemoryScore(_ v: Int) {
        memoryScore = max(memoryScore, v)
        UserDefaults.standard.set(memoryScore, forKey: "score_memory")
    }
    func saveOceanScore(_ v: Int) {
        oceanScore = max(oceanScore, v)
        UserDefaults.standard.set(oceanScore, forKey: "score_ocean")
    }
    func resetAllScores() {
        triviaScore = 0; memoryScore = 0; oceanScore = 0
        ["score_trivia","score_memory","score_ocean"].forEach {
            UserDefaults.standard.set(0, forKey: $0)
        }
    }

    // MARK: Preference helpers
    func setSkipMapInfo(_ v: Bool)   { skipMapInfo   = v; UserDefaults.standard.set(v, forKey: "skip_mapInfo")   }
    func setSkipOceanInfo(_ v: Bool) { skipOceanInfo = v; UserDefaults.standard.set(v, forKey: "skip_oceanInfo") }
    func setSkipMemoryInfo(_ v: Bool) { skipMemoryInfo = v; UserDefaults.standard.set(v, forKey: "skip_memoryInfo") }

    func setTheme(_ t: AppTheme) {
        theme = t
        UserDefaults.standard.set(t.rawValue, forKey: "appTheme")
    }
    func resetPreferences() {
        setSkipMapInfo(false)
        setSkipOceanInfo(false)
        setSkipMemoryInfo(false)
    }

    func resetAllAppData() {
        resetAllScores()
        resetPreferences()
        setTheme(.mint)
    }
}
