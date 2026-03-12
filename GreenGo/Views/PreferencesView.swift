import SwiftUI

struct PreferencesView: View {
    @EnvironmentObject private var appState: AppState
    @State private var showResetConfirm = false

    var body: some View {
        ZStack {
            appState.theme.background.ignoresSafeArea()
            List {
                Section("Appearance") {
                    ForEach(AppTheme.allCases, id: \.self) { theme in
                        Button { appState.setTheme(theme) } label: {
                            HStack {
                                Circle().fill(theme.appearanceDot).frame(width: 22, height: 22)
                                Text(theme.displayName).foregroundStyle(appState.theme.text)
                                Spacer()
                                if appState.theme == theme {
                                    Image(systemName: "checkmark").foregroundStyle(.green)
                                }
                            }
                        }
                        .listRowBackground(appState.theme.cardBackground)
                    }
                }
                Section("High Scores") {
                    scoreRow("Eco Trivia",    value: appState.triviaScore)
                        .listRowBackground(appState.theme.cardBackground)
                    scoreRow("Wild Recall",   value: appState.memoryScore)
                        .listRowBackground(appState.theme.cardBackground)
                    scoreRow("Reef Rescuers", value: appState.oceanScore)
                        .listRowBackground(appState.theme.cardBackground)
                }
                Section("Reset") {
                    Button(role: .destructive) { showResetConfirm = true } label: {
                        Label("Reset All App Data", systemImage: "arrow.counterclockwise")
                    }
                    .listRowBackground(appState.theme.cardBackground)
                }
                Section("App Info") {
                    labelRow("App Name", "GreenGo")
                    labelRow("Version",  "1.0")
                    labelRow("Platform", "iOS 26+")
                }
            }
            .scrollContentBackground(.hidden)
            .listStyle(.insetGrouped)
            .safeAreaInset(edge: .top, spacing: 0) {
                navBar(title: "Preferences", back: .home)
            }
        }
        .confirmationDialog("Reset all app data?", isPresented: $showResetConfirm, titleVisibility: .visible) {
            Button("Reset", role: .destructive) { appState.resetAllAppData() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This resets high scores and restores the default theme.")
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    @ViewBuilder
    private func scoreRow(_ label: String, value: Int) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text("\(value)").foregroundStyle(.secondary).font(.custom("AlumniSans-Bold", size: 15))
        }
    }

    @ViewBuilder
    private func labelRow(_ key: String, _ value: String) -> some View {
        HStack {
            Text(key)
            Spacer()
            Text(value).foregroundStyle(.secondary).font(.custom("CreativeThoughts-Regular", size: 14))
        }
    }
}
