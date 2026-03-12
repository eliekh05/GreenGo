import SwiftUI
import CoreMotion

// MARK: - _PedometerRelay (NOT @MainActor)
// The CMPedometer callback closure MUST be created in a non-isolated context.
// If created inside a @MainActor method, Swift 6 marks it @MainActor-isolated,
// and CMPedometerUpdateQueue delivery trips _dispatch_assert_queue_fail.
// Solution: move startUpdates() call INTO this relay class so the closure
// is created non-isolated. Same logic applies to the Timer closure.
final class _PedometerRelay: @unchecked Sendable {
    nonisolated(unsafe) weak var owner: PedometerManager?
    private let cmpedo = CMPedometer()
    private var timer:  Timer?

    func startUpdates(from date: Date) {
        cmpedo.startUpdates(from: date) { [weak self] data, _ in
            guard let self, let data else { return }
            let steps = data.numberOfSteps.intValue
            let dist  = data.distance?.doubleValue ?? 0
            DispatchQueue.main.async {
                self.owner?.applyUpdate(steps: steps, dist: dist)
            }
        }
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            DispatchQueue.main.async {
                self.owner?.applyTimerTick()
            }
        }
    }

    func stop() {
        cmpedo.stopUpdates()
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - PedometerManager
@MainActor
final class PedometerManager: ObservableObject {
    @Published var steps:       Int          = 0
    @Published var distanceKm:  Double       = 0
    @Published var elapsed:     TimeInterval = 0
    @Published var isRunning:   Bool         = false

    fileprivate let relay = _PedometerRelay()
    private var startDate:            Date?
    private var accumulated:          TimeInterval = 0
    private var accumulatedSteps:     Int    = 0
    private var accumulatedDistanceM: Double = 0
    private var segmentSteps:         Int    = 0
    private var segmentDistanceM:     Double = 0

    init() { relay.owner = self }

    var timeString: String {
        let m = Int(elapsed) / 60
        let s = Int(elapsed) % 60
        return String(format: "%02d:%02d", m, s)
    }

    func start() {
        guard CMPedometer.isStepCountingAvailable() else { return }
        let status = CMPedometer.authorizationStatus()
        guard status == .authorized || status == .notDetermined else { return }
        guard !isRunning else { return }
        let start = Date()
        startDate = start
        isRunning = true
        relay.startUpdates(from: start)
    }

    func pause() {
        guard isRunning else { return }
        isRunning = false
        relay.stop()
        if let s = startDate { accumulated += Date().timeIntervalSince(s) }
        accumulatedSteps     += segmentSteps
        accumulatedDistanceM += segmentDistanceM
        segmentSteps      = 0
        segmentDistanceM  = 0
        steps             = accumulatedSteps
        distanceKm        = accumulatedDistanceM / 1000
        startDate         = nil
    }

    func reset() {
        pause()
        steps             = 0
        distanceKm        = 0
        elapsed           = 0
        accumulated       = 0
        accumulatedSteps  = 0
        accumulatedDistanceM = 0
        segmentSteps      = 0
        segmentDistanceM  = 0
    }

    fileprivate func applyUpdate(steps newSteps: Int, dist newDist: Double) {
        segmentSteps     = newSteps
        segmentDistanceM = newDist
        steps            = accumulatedSteps + newSteps
        distanceKm       = (accumulatedDistanceM + newDist) / 1000
    }

    fileprivate func applyTimerTick() {
        guard let s = startDate else { return }
        elapsed = accumulated + Date().timeIntervalSince(s)
    }
}

// MARK: - PedometerView
struct PedometerView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var pedo = PedometerManager()
    @State private var walkPhase = false

    private let green = Color(red: 0.08, green: 0.52, blue: 0.12)

    var body: some View {
        ZStack {
            appState.theme.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 24) {
                    ZStack {
                        Circle().fill(green.opacity(0.10)).frame(width: 130, height: 130)
                        if let img = UIImage(named: "stickman") {
                            Image(uiImage: img).resizable().scaledToFit().frame(width: 70, height: 70)
                        } else {
                            Image(systemName: "figure.walk")
                                .font(.system(size: 56)).foregroundStyle(green)
                        }
                    }
                    .padding(.top, 16)
                    .offset(x: pedo.isRunning ? (walkPhase ? 10 : -10) : 0,
                            y: pedo.isRunning ? (walkPhase ? -2 : 2) : 0)
                    .rotationEffect(.degrees(pedo.isRunning ? (walkPhase ? 8 : -8) : 0))
                    .onAppear { if pedo.isRunning { startWalkAnimation() } }
                    .onChange(of: pedo.isRunning) { _, running in
                        running ? startWalkAnimation() : stopWalkAnimation()
                    }

                    LazyVGrid(
                        columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                        spacing: 14
                    ) {
                        statCard(value: "\(pedo.steps)",     label: "Steps",    sf: "figure.walk", color: green)
                        statCard(value: String(format: "%.2f", pedo.distanceKm) + " km",
                                 label: "Distance", sf: "map",         color: .blue)
                        statCard(value: pedo.timeString,     label: "Time",     sf: "clock",       color: .orange)
                    }
                    .padding(.horizontal, 16)

                    HStack(spacing: 12) {
                        ctrlBtn(label: pedo.isRunning ? "Pause" : "Start",
                                icon:  pedo.isRunning ? "pause.fill" : "play.fill",
                                color: pedo.isRunning ? .orange : green) {
                            pedo.isRunning ? pedo.pause() : pedo.start()
                        }
                        ctrlBtn(label: "Reset", icon: "arrow.counterclockwise",
                                color: .red.opacity(0.80)) { pedo.reset() }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 30)
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                navBar(title: "Pedometer", back: .functionality)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onDisappear { pedo.pause() }
    }

    private func startWalkAnimation() {
        withAnimation(.easeInOut(duration: 0.34).repeatForever(autoreverses: true)) { walkPhase = true }
    }
    private func stopWalkAnimation() {
        withAnimation(.easeOut(duration: 0.15)) { walkPhase = false }
    }

    @ViewBuilder
    private func statCard(value: String, label: String, sf: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: sf).font(.custom("CreativeThoughts-Regular", size: 22)).foregroundStyle(color)
            Text(value)
                .font(.custom("AlumniSans-Bold", size: 18)).foregroundStyle(color)
                .minimumScaleFactor(0.6).lineLimit(1)
            Text(label).font(.system(size: 11)).foregroundStyle(appState.theme.mutedText)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 16)
        .background(appState.theme.cardBackground, in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: color.opacity(0.12), radius: 6)
    }

    @ViewBuilder
    private func ctrlBtn(label: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack { Image(systemName: icon); Text(label).font(.custom("AlumniSans-Bold", size: 18)) }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity).padding(.vertical, 16)
                .background(color, in: RoundedRectangle(cornerRadius: 14))
        }
    }
}
