import SwiftUI
import AVFoundation

// MARK: - Sound player
private final class SoundPlayer {
    nonisolated(unsafe) static let shared = SoundPlayer()
    private var players: [String: AVAudioPlayer] = [:]

    private init() {
        for name in ["Ding", "Buzzer", "Touch"] {
            if let url = Bundle.main.url(forResource: name, withExtension: "mp4") {
                players[name] = try? AVAudioPlayer(contentsOf: url)
                players[name]?.prepareToPlay()
            }
        }
    }

    func play(_ name: String) {
        players[name]?.currentTime = 0
        players[name]?.play()
    }
}

// MARK: - Sprite
struct OceanSprite: Identifiable {
    let id:      String
    var x:       CGFloat
    var y:       CGFloat
    let size:    CGFloat = 50
    var visible: Bool
}

// MARK: - Game model (faithful to AIA Ocean.scm / Ocean.bky)
@MainActor
final class ReefRescuersGame: ObservableObject {
    @Published var score:    Int  = 0
    @Published var running:  Bool = false
    @Published var gameOver: Bool = false

    // Sprites — starting positions match AIA SCM (will be respawned on start)
    @Published var chipsbag        = OceanSprite(id: "chips",           x: 13,  y: -50, visible: false)
    @Published var greenplasticbag = OceanSprite(id: "greenplasticbag", x: 163, y: -50, visible: true)
    @Published var oldshoes        = OceanSprite(id: "oldshoes",        x: 196, y: -50, visible: false)
    @Published var yellowbottle    = OceanSprite(id: "yellowbottle",    x: 149, y: -50, visible: false)
    @Published var fish            = OceanSprite(id: "fish",            x: 63,  y: -50, visible: true)
    @Published var tire            = OceanSprite(id: "cartire",         x: 134, y: -50, visible: true)
    // Platform sprite: full-width, 20pt tall, pinned to canvas bottom
    @Published var platform        = OceanSprite(id: "oceanplatform",   x: 0,   y: 0,   visible: true)
    // Recycling bin: 60×60, sits just above the platform
    @Published var recyclingBin    = OceanSprite(id: "Recyclebin",      x: 94,  y: 0,   visible: true)

    var canvasWidth:  CGFloat = 390
    var canvasHeight: CGFloat = 700

    private let platformHeight: CGFloat = 20
    private let binSize:        CGFloat = 60

    private var platformY:  CGFloat { canvasHeight - platformHeight }
    private var binY:       CGFloat { platformY - binSize }
    private var tickTimer:  Timer?

    func initCanvas(width w: CGFloat, height h: CGFloat) {
        canvasWidth  = w
        canvasHeight = h
        platform.x  = 0
        platform.y  = platformY
        recyclingBin.x = w / 2 - binSize / 2
        recyclingBin.y = binY
    }

    func start() {
        guard !running else { return }
        score    = 0
        gameOver = false
        running  = true
        spawnAll()
        startTick()
    }

    func reset() {
        stopTick()
        running  = false
        gameOver = false
        score    = 0
        spawnAll()
        running  = true
        startTick()
    }

    func stop() { stopTick(); running = false }

    /// Drag bin to absolute X position on canvas
    func dragBin(toX x: CGFloat) {
        guard running else { return }
        recyclingBin.x = max(0, min(x - binSize / 2, canvasWidth - binSize))
        recyclingBin.y = binY
    }

    /// Move bin left by a fixed step (button control)
    func moveBinLeft() {
        guard running else { return }
        recyclingBin.x = max(0, recyclingBin.x - 24)
        recyclingBin.y = binY
    }

    /// Move bin right by a fixed step (button control)
    func moveBinRight() {
        guard running else { return }
        recyclingBin.x = min(canvasWidth - binSize, recyclingBin.x + 24)
        recyclingBin.y = binY
    }

    // MARK: - Private

    private func spawnAll() {
        respawn(&tire); respawn(&greenplasticbag); respawn(&fish)
        respawn(&chipsbag); respawn(&yellowbottle); respawn(&oldshoes)
        chipsbag.visible     = false
        yellowbottle.visible = false
        oldshoes.visible     = false
        platform.x  = 0
        platform.y  = platformY
        recyclingBin.x = canvasWidth / 2 - binSize / 2
        recyclingBin.y = binY
    }

    private func startTick() {
        tickTimer?.invalidate()
        // iOS 26 beta: Task { @MainActor } trips _dispatch_assert_queue_fail from Timer
        // callbacks. DispatchQueue.main.async is safe from any non-isolated context.
        tickTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async { [weak self] in self?.tick() }
        }
    }

    private func stopTick() { tickTimer?.invalidate(); tickTimer = nil }

    private func tick() {
        guard running else { return }

        // AIA Clock speed = 3px per tick
        drop(&tire);            drop(&greenplasticbag); drop(&fish)
        if score > 1  { chipsbag.visible     = true; drop(&chipsbag) }
        if score > 8  { yellowbottle.visible = true; drop(&yellowbottle) }
        if score > 20 { oldshoes.visible     = true; drop(&oldshoes) }

        // Keep platform and bin pinned
        platform.y     = platformY
        recyclingBin.y = binY

        // Collision detection
        hitTest(&chipsbag,        isFish: false)
        hitTest(&greenplasticbag, isFish: false)
        hitTest(&oldshoes,        isFish: false)
        hitTest(&yellowbottle,    isFish: false)
        hitTest(&tire,            isFish: false)
        hitTest(&fish,            isFish: true)
    }

    private func drop(_ s: inout OceanSprite) {
        guard s.visible else { return }
        s.y += 3
    }

    private func hitTest(_ s: inout OceanSprite, isFish: Bool) {
        guard s.visible else { return }
        // Hit platform floor → respawn (missed trash, no penalty like AIA)
        if s.y + s.size >= platformY {
            respawn(&s)
        } else if overlaps(s, recyclingBin) {
            if isFish {
                // AIA: catching fish → instant game over
                stopTick(); running = false; gameOver = true
                s.y = -200
                SoundPlayer.shared.play("Buzzer")
            } else {
                score += 1
                respawn(&s)
                SoundPlayer.shared.play("Ding")
            }
        }
    }

    private func respawn(_ s: inout OceanSprite) {
        s.x = CGFloat.random(in: 1...max(1, canvasWidth - s.size))
        s.y = -s.size
    }

    private func overlaps(_ a: OceanSprite, _ b: OceanSprite) -> Bool {
        guard a.visible && b.visible else { return false }
        return a.x < b.x + b.size && a.x + a.size > b.x &&
               a.y < b.y + b.size && a.y + a.size > b.y
    }
}

// MARK: - OceanInfoView
struct OceanInfoView: View {
    @EnvironmentObject private var appState: AppState
    @State private var skip = false

    var body: some View {
        ZStack {
            appState.theme.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    backBtn { appState.screen = .games }.padding(.top, 8)
                    HStack(spacing: 12) {
                        if let img = UIImage(named: "oceangameicon") {
                            Image(uiImage: img).resizable().scaledToFit()
                                .frame(width: 52, height: 52).clipShape(Circle())
                        }
                        Text("Reef Rescuers")
                            .font(.custom("AlumniSans-Bold", size: 30))
                            .foregroundStyle(appState.theme.accent)
                    }
                    Text("The oceans are polluted. Your goal is to clean it out as many trash as possible without killing the fish.")
                        .font(.custom("CreativeThoughts-Regular", size: 16))
                        .foregroundStyle(appState.theme.text)
                        .padding(14)
                        .background(Color(red: 0.04, green: 0.32, blue: 0.70).opacity(0.12),
                                    in: RoundedRectangle(cornerRadius: 12))
                    Text("How to Play").font(.custom("AlumniSans-Bold", size: 20)).foregroundStyle(appState.theme.text)
                    ForEach([
                        "Drag the recycling bin left and right to catch falling trash.",
                        "Catch chips bags, plastic bags, bottles, tyres, and shoes to score.",
                        "More trash types unlock as your score grows.",
                        "DON'T catch the fish — it ends the game immediately!",
                    ], id: \.self) { rule in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(appState.theme.accent)
                            Text(rule).font(.custom("CreativeThoughts-Regular", size: 15)).foregroundStyle(appState.theme.text)
                        }
                    }
                    Toggle("Don't show this again", isOn: $skip)
                        .font(.custom("CreativeThoughts-Regular", size: 15))
                    Button {
                        appState.setSkipOceanInfo(skip)
                        appState.screen = .ocean
                    } label: {
                        Text("Play Now!")
                            .font(.custom("AlumniSans-Bold", size: 20)).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding()
                            .background(appState.theme.accent, in: RoundedRectangle(cornerRadius: 14))
                    }
                }
                .padding(20)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

// MARK: - OceanGameView
// AIA layout: HUD bar (Start/Reset + Score + Home) at top, canvas fills rest,
// oceanplatform pinned to canvas bottom, recycling bin sits just above platform.
// Drag gesture on canvas surface to move bin left and right.
struct OceanGameView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var game = ReefRescuersGame()

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                // ── HUD bar (faithful to AIA HorizontalArrangement1) ──
                HStack {
                    Button {
                        SoundPlayer.shared.play("Touch")
                        if game.running { game.reset() } else { game.start() }
                    } label: {
                        Text(game.running ? "Reset" : "Start")
                            .font(.custom("AlumniSans-Bold", size: 15))
                            .foregroundStyle(.black)
                            .frame(width: 60, height: 35)
                            .background(.white.opacity(0.85), in: Capsule())
                    }
                    Spacer()
                    VStack(spacing: 0) {
                        Text("Score")
                            .font(.custom("AlumniSans-Bold", size: 13))
                            .foregroundStyle(.white.opacity(0.85))
                        Text("\(game.score)")
                            .font(.custom("AlumniSans-Bold", size: 22))
                            .foregroundStyle(Color(red: 1, green: 0.85, blue: 0))
                    }
                    .shadow(color: .black.opacity(0.6), radius: 2)
                    Spacer()
                    Button {
                        SoundPlayer.shared.play("Touch"); game.stop(); appState.screen = .games
                    } label: {
                        Image(systemName: "house.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.6), radius: 2)
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(Color(red: 0.03, green: 0.10, blue: 0.28))
                .background { Color.clear.ignoresSafeArea(edges: .top) }

                // ── Canvas area (fills remaining space) ──
                ZStack(alignment: .topLeading) {
                    // Ocean background
                    if let bg = UIImage(named: "ocean") {
                        Image(uiImage: bg).resizable().scaledToFill()
                            .frame(width: geo.size.width)
                            .clipped()
                    } else {
                        Color(red: 0.03, green: 0.25, blue: 0.60)
                    }

                    // Drag surface
                    Color.clear.contentShape(Rectangle())
                        .gesture(DragGesture(minimumDistance: 0)
                            .onChanged { v in game.dragBin(toX: v.location.x) })

                    // Platform (full-width, pinned to bottom)
                    platformSprite(game.platform, canvasWidth: geo.size.width)

                    // Falling sprites
                    sprite(game.tire)
                    sprite(game.chipsbag)
                    sprite(game.greenplasticbag)
                    sprite(game.oldshoes)
                    sprite(game.yellowbottle)
                    sprite(game.fish)

                    // Recycling bin
                    binSprite(game.recyclingBin)



                    // Game Over overlay
                    if game.gameOver {
                        Color.black.opacity(0.55)
                        VStack(spacing: 18) {
                            Text("Game Over")
                                .font(.custom("GameOfSquids", size: 36))
                                .foregroundStyle(.white).shadow(radius: 6)
                            Text("Score: \(game.score)")
                                .font(.custom("AlumniSans-Bold", size: 26))
                                .foregroundStyle(Color(red: 1, green: 0.85, blue: 0))
                            HStack(spacing: 16) {
                                Button {
                                    SoundPlayer.shared.play("Touch"); game.reset()
                                } label: {
                                    Text("Play Again")
                                        .font(.custom("AlumniSans-Bold", size: 18))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 20).padding(.vertical, 12)
                                        .background(Color(red: 0.08, green: 0.52, blue: 0.12),
                                                    in: RoundedRectangle(cornerRadius: 14))
                                }
                                Button { appState.screen = .games } label: {
                                    Text("Exit")
                                        .font(.custom("AlumniSans-Bold", size: 18))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 20).padding(.vertical, 12)
                                        .background(Color.gray.opacity(0.7),
                                                    in: RoundedRectangle(cornerRadius: 14))
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }

                    // Start prompt (before first start)
                    if !game.running && !game.gameOver {
                        Button {
                            SoundPlayer.shared.play("Touch")
                            game.start()
                        } label: {
                            Text("Start")
                                .font(.custom("AlumniSans-Bold", size: 28))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 44).padding(.vertical, 18)
                                .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 22))
                                .shadow(radius: 12)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .onAppear {
                    let hudH: CGFloat = 55  // approx HUD height
                    game.initCanvas(width: geo.size.width, height: geo.size.height - hudH)
                }
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .onChange(of: game.gameOver) { _, over in if over { appState.saveOceanScore(game.score) } }
        .toolbar(.hidden, for: .navigationBar)
        .onDisappear { game.stop() }
    }

    // Platform: full canvas width, short (20pt), pinned to bottom
    @ViewBuilder
    private func platformSprite(_ s: OceanSprite, canvasWidth: CGFloat) -> some View {
        if let img = UIImage(named: s.id) {
            Image(uiImage: img).resizable().scaledToFill()
                .frame(width: canvasWidth, height: 20)
                .clipped()
                .position(x: canvasWidth / 2, y: s.y + 10)
        }
    }

    @ViewBuilder
    private func binSprite(_ s: OceanSprite) -> some View {
        Group {
            if let img = UIImage(named: s.id) {
                Image(uiImage: img).resizable().scaledToFit()
                    .frame(width: 60, height: 60)
            } else {
                RoundedRectangle(cornerRadius: 6).fill(Color.green.opacity(0.8))
                    .frame(width: 60, height: 60)
                    .overlay(Text("BIN").font(.system(size: 10)).foregroundStyle(.white))
            }
        }
        .position(x: s.x + 30, y: s.y + 30)
    }

    @ViewBuilder
    private func sprite(_ s: OceanSprite) -> some View {
        if s.visible {
            Group {
                if let img = UIImage(named: s.id) {
                    Image(uiImage: img).resizable().scaledToFit()
                        .frame(width: s.size, height: s.size)
                } else {
                    RoundedRectangle(cornerRadius: 4).fill(Color.orange.opacity(0.7))
                        .frame(width: s.size, height: s.size)
                        .overlay(Text(s.id).font(.system(size: 7)).foregroundStyle(.white))
                }
            }
            .position(x: s.x + s.size / 2, y: s.y + s.size / 2)
        }
    }
}
