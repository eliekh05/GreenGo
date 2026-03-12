import SwiftUI

private struct NavTile: Identifiable {
    let id   = UUID()
    let title: String
    let sub:   String
    let icon:  String
    let color: Color
    let image: String
    let dest:  Screen
}

struct HomeView: View {
    @EnvironmentObject private var appState: AppState

    private let green = Color(red: 0.08, green: 0.52, blue: 0.10)
    private let blue  = Color(red: 0.10, green: 0.38, blue: 0.82)

    private var tiles: [NavTile] { [
        NavTile(title: "Maps",          sub: "Eco-friendly locations",       icon: "map.fill",           color: green, image: "pin",           dest: .mapInfo),
        NavTile(title: "Functionality", sub: "Translator & Pedometer",       icon: "gearshape.fill",     color: blue,  image: "languagesphoto", dest: .functionality),
        NavTile(title: "Games",         sub: "Learn while you play",         icon: "gamecontroller.fill", color: Color(red: 0.78, green: 0.22, blue: 0.08), image: "game-controller", dest: .games),

    ] }

    var body: some View {
        ZStack {
            appState.theme.background.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    ForEach(tiles) { tile in
                        TileCard(tile: tile)
                    }
                    HStack(spacing: 12) {
                        smallBtn("About",      icon: "info.circle.fill",  color: Color(red: 0.35, green: 0.18, blue: 0.62)) { appState.screen = .about }
                        smallBtn("Contact Us", icon: "envelope.fill",     color: Color(red: 0.05, green: 0.52, blue: 0.44)) { appState.screen = .contact }
                    }
                    HStack(spacing: 12) {
                        smallBtn("Preferences", icon: "slider.horizontal.3", color: Color(red: 0.40, green: 0.40, blue: 0.40)) { appState.screen = .preferences }
                    }
                    .padding(.bottom, 30)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }
            .safeAreaInset(edge: .top, spacing: 0) { header }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: Header
    private var header: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                if let img = UIImage(named: "GreenGologocopy") {
                    Image(uiImage: img)
                        .resizable().scaledToFill()
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 0) {
                        Text("Green").foregroundStyle(green).font(.custom("YBDarkChocolateFudge", size: 28))
                        Text("Go").foregroundStyle(Color(red: 0.10, green: 0.38, blue: 0.82)).font(.custom("YBDarkChocolateFudge", size: 28))
                    }
                    Text("Sustainable Travel Companion")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
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

    // MARK: Small bottom buttons
    @ViewBuilder
    private func smallBtn(_ label: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                Text(label).font(.custom("YBDarkChocolateFudge", size: 16))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(color, in: RoundedRectangle(cornerRadius: 14))
        }
    }
}

// MARK: - Tile Card
private struct TileCard: View {
    @EnvironmentObject private var appState: AppState
    let tile: NavTile

    var body: some View {
        Button { navigate() } label: {
            HStack(spacing: 14) {
                Group {
                    if let img = UIImage(named: tile.image) {
                        Image(uiImage: img).resizable().scaledToFill()
                            .frame(width: 64, height: 64).clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        Image(systemName: tile.icon).font(.system(size: 30))
                            .foregroundStyle(.white)
                            .frame(width: 64, height: 64)
                            .background(tile.color, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(tile.title).font(.custom("YBDarkChocolateFudge", size: 20)).foregroundStyle(tile.color)
                    Text(tile.sub).font(.system(size: 13)).foregroundStyle(appState.theme.mutedText)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(tile.color).font(.custom("AlumniSans-Bold", size: 15))
            }
            .padding(16)
            .background(appState.theme.cardBackground, in: RoundedRectangle(cornerRadius: 18))
            .shadow(color: tile.color.opacity(0.12), radius: 8, x: 0, y: 4)
        }
    }

    private func navigate() {
        if tile.dest == .mapInfo {
            appState.screen = appState.skipMapInfo ? .map : .mapInfo
        } else {
            appState.screen = tile.dest
        }
    }
}
