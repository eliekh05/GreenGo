import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var showResetAllConfirm = false

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
                    Button(role: .destructive) { showResetAllConfirm = true } label: {
                        Label("Reset All App Data", systemImage: "trash")
                    }
                    .listRowBackground(appState.theme.cardBackground)
                }

            }
            .scrollContentBackground(.hidden)
            .listStyle(.insetGrouped)
            .safeAreaInset(edge: .top, spacing: 0) {
                navBar(title: "Settings", back: .home)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .confirmationDialog("Reset all app data?", isPresented: $showResetAllConfirm, titleVisibility: .visible) {
            Button("Reset", role: .destructive) { appState.resetAllAppData() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This resets high scores, shows all info screens again, and restores the default theme.")
        }
    }

    @ViewBuilder
    private func scoreRow(_ label: String, value: Int) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text("\(value)").foregroundStyle(.secondary).font(.custom("AlumniSans-Bold", size: 15))
        }
    }

}
