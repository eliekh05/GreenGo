import SwiftUI

@main
struct GreenGoApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .preferredColorScheme(appState.theme == .dark ? .dark : .light)
        }
    }
}
