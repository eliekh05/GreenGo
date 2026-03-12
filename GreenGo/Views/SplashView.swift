import SwiftUI
import AVFoundation

// MARK: - SplashCoordinator
// A class (reference type) that owns the AVPlayer and handles NotificationCenter
// callbacks. Being a class allows proper [weak self] capture.
// @MainActor ensures all mutations happen on the main thread.
@MainActor
private final class SplashCoordinator: ObservableObject {
    @Published var player: AVPlayer? = nil
    private var finished = false
    private var observer: NSObjectProtocol? = nil

    // Called by SplashView once appState is available
    var onFinish: (() -> Void)? = nil

    func start() {
        Task {
            try? await Task.sleep(for: .milliseconds(1500))
            startVideo()
        }
    }

    private func startVideo() {
        if let url = Bundle.main.url(forResource: "GreenGo2", withExtension: "mp4") {
            prepareAndPlay(url: url); return
        }
        if let path = Bundle.main.path(forResource: "GreenGo2", ofType: "mp4") {
            prepareAndPlay(url: URL(fileURLWithPath: path)); return
        }
        if let res = Bundle.main.resourceURL?.appendingPathComponent("GreenGo2.mp4"),
           FileManager.default.fileExists(atPath: res.path) {
            prepareAndPlay(url: res); return
        }
        print("[SplashView] GreenGo2.mp4 not found — skipping to home.")
        go()
    }

    private func prepareAndPlay(url: URL) {
        let p = AVPlayer(url: url)
        player = p

        // SplashCoordinator is a class — [weak self] is valid here.
        observer = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: p.currentItem,
            queue: .main
        ) { [weak self] _ in
        // Swift 6: NotificationCenter callback on queue:.main is still a nonisolated context.
            // Task { @MainActor } is the correct way to hop back to the actor.
            Task { @MainActor [weak self] in self?.go() }
        }

        // Safety cap: navigate after 8 s even if video stalls.
        Task {
            try? await Task.sleep(for: .seconds(8))
            go()
        }

        p.play()
    }

    func go() {
        guard !finished else { return }
        finished = true
        player?.pause()
        if let obs = observer { NotificationCenter.default.removeObserver(obs) }
        onFinish?()
    }
}

// MARK: - SplashView
struct SplashView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var coordinator = SplashCoordinator()

    var body: some View {
        ZStack {
            Color(red: 0.816, green: 1.0, blue: 0.973).ignoresSafeArea()
            if let player = coordinator.player {
                VideoPlayerView(player: player).ignoresSafeArea()
            }
        }
        .onAppear {
            coordinator.onFinish = { appState.screen = .home }
            coordinator.start()
        }
        .toolbar(.hidden, for: .navigationBar)
        .statusBarHidden(true)
        .allowsHitTesting(false)
    }
}

// MARK: - Fullscreen AVPlayer wrapper
private struct VideoPlayerView: UIViewRepresentable {
    let player: AVPlayer
    func makeUIView(context: Context) -> _PlayerView { _PlayerView(player: player) }
    func updateUIView(_ uiView: _PlayerView, context: Context) {}
}

private final class _PlayerView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    private var pLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    init(player: AVPlayer) {
        super.init(frame: .zero)
        pLayer.player       = player
        pLayer.videoGravity = .resizeAspectFill
    }
    required init?(coder: NSCoder) { fatalError() }
    override func layoutSubviews() { super.layoutSubviews(); pLayer.frame = bounds }
}
