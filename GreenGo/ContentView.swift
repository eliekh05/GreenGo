import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            switch appState.screen {
            case .splash:               SplashView()
            case .home:                 HomeView()
            case .map:                  MapView()
            case .mapInfo:              MapInfoView()
            case .functionality:        FunctionalityView()
            case .translator:           TranslatorView()
            case .pedometer:            PedometerView()
            case .games:                GamesView()
            case .memoryInfo:           MemoryInfoView()
            case .wildRecall:           WildRecallView()
            case .oceanInfo:            OceanInfoView()
            case .ocean:                OceanGameView()
            case .trivia:               TriviaView()
            case .triviaScore(let s):   TriviaScoreView(score: s)
            case .settings:             SettingsView()
            case .about:                AboutView()
            case .contact:              ContactView()
            case .preferences:          PreferencesView()
            }
        }
        .animation(.easeInOut(duration: 0.22), value: appState.screen)
    }
}
