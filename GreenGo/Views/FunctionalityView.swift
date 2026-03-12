import SwiftUI

struct FunctionalityView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ZStack {
            appState.theme.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 18) {
                    toolCard(
                        title: "Translator",
                        sub: "Speak or type text, translate into 20+ languages",
                        sfIcon: "globe",
                        imageName: "languagesphoto",
                        color: Color(red: 0.05, green: 0.38, blue: 0.82)
                    ) { appState.screen = .translator }

                    toolCard(
                        title: "Pedometer",
                        sub: "Count steps, track distance and time on any walk",
                        sfIcon: "figure.walk",
                        imageName: "pedometer",
                        color: Color(red: 0.08, green: 0.52, blue: 0.12)
                    ) { appState.screen = .pedometer }
                }
                .padding(16)
            }
            // ── iOS 26 gap fix: safeAreaInset pins the nav bar to the top
            // so the ScrollView's own safe-area inset is exactly the nav bar height
            // — no double-counting, no blank gap.
            .safeAreaInset(edge: .top, spacing: 0) {
                navBar(title: "Functionality", back: .home)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    @ViewBuilder
    private func toolCard(title: String, sub: String, sfIcon: String,
                          imageName: String, color: Color,
                          action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Group {
                    if let img = UIImage(named: imageName) {
                        Image(uiImage: img).resizable().scaledToFill()
                            .frame(width: 72, height: 72).clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    } else {
                        Image(systemName: sfIcon).font(.system(size: 32))
                            .foregroundStyle(.white)
                            .frame(width: 72, height: 72)
                            .background(color, in: RoundedRectangle(cornerRadius: 14))
                    }
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text(title).font(.custom("AlumniSans-Bold", size: 20)).foregroundStyle(color)
                    Text(sub).font(.system(size: 13)).foregroundStyle(appState.theme.mutedText)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(color).font(.custom("AlumniSans-Bold", size: 15))
            }
            .padding(16)
            .background(appState.theme.cardBackground, in: RoundedRectangle(cornerRadius: 18))
            .shadow(color: color.opacity(0.12), radius: 8, x: 0, y: 4)
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Shared nav bar  (used via .safeAreaInset on every screen)
// ─────────────────────────────────────────────────────────────────────────────
//
// iOS 26 gap fix:
// Using .safeAreaInset(edge: .top, spacing: 0) { navBar(...) } instead of
// stacking the bar in a VStack means iOS correctly sets the scroll view's top
// inset to *only* the navBar height — not navBarHeight + navigationBarHeight.
// The .regularMaterial background with .ignoresSafeArea(edges: .top) still
// fills the Dynamic Island / status bar area visually.

@MainActor @ViewBuilder
func navBar(title: String, back: Screen, home: Bool = true) -> some View {
    _NavBar(title: title, back: back, showHome: home)
}

struct _NavBar: View {
    @EnvironmentObject private var appState: AppState
    let title:    String
    let back:     Screen
    let showHome: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { appState.screen = back } label: {
                    Image(systemName: "chevron.left")
                        .font(.custom("AlumniSans-Bold", size: 18))
                        .foregroundStyle(appState.theme.text)
                }
                Spacer()
                Text(title)
                    .font(.custom("AlumniSans-Bold", size: 22))
                    .foregroundStyle(appState.theme.text)
                Spacer()
                if showHome {
                    Button { appState.screen = .home } label: {
                        Image(systemName: "house.fill").foregroundStyle(appState.theme.mutedText)
                    }
                } else {
                    Color.clear.frame(width: 28)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background {
                Rectangle()
                    .fill(.regularMaterial)
                    .ignoresSafeArea(edges: .top)
            }
            Divider()
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Shared back button (used in info screens without full nav bar)
// ─────────────────────────────────────────────────────────────────────────────
@MainActor @ViewBuilder
func backBtn(action: @escaping () -> Void) -> some View {
    Button(action: action) {
        HStack(spacing: 4) {
            Image(systemName: "chevron.left")
            Text("Back")
        }
        .font(.custom("AlumniSans-Bold", size: 16))
        .foregroundStyle(Color(red: 0.08, green: 0.50, blue: 0.15))
    }
}
