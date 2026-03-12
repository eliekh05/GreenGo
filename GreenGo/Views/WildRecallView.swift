import SwiftUI

// MARK: - Card model
struct MemCard: Identifiable {
    let id      = UUID()
    let pairID:  Int
    let imgName: String
    var flipped  = false
    var matched  = false
}

// MARK: - Game state
@MainActor
final class WildRecallGame: ObservableObject {
    // All available animal pairs
    static let allPairs = ["a1","a2","a3","a4","a5","a6","a7","a8"]
    // Number of pairs per game — pick 6 of 8 each time for variety
    static let pairsPerGame = 6

    @Published var cards:      [MemCard] = []
    @Published var score:      Int       = 0
    @Published var matched:    Int       = 0
    @Published var gameOver:   Bool      = false
    @Published var totalPairs: Int       = pairsPerGame

    private var flippedIDs: [UUID] = []
    private var busy = false

    init() { deal() }

    func deal() {
        score = 0; matched = 0; gameOver = false; flippedIDs = []; busy = false
        // Shuffle the full list and take the first `pairsPerGame`
        let chosen = Self.allPairs.shuffled().prefix(Self.pairsPerGame)
        totalPairs = chosen.count
        var deck: [MemCard] = []
        for (i, name) in chosen.enumerated() {
            deck.append(MemCard(pairID: i, imgName: name))
            deck.append(MemCard(pairID: i, imgName: name))
        }
        cards = deck.shuffled()
    }

    func tap(_ card: MemCard) {
        guard !busy,
              let idx = cards.firstIndex(where: { $0.id == card.id }),
              !cards[idx].flipped,
              !cards[idx].matched,
              flippedIDs.count < 2 else { return }

        cards[idx].flipped = true
        flippedIDs.append(card.id)
        if flippedIDs.count == 2 { check() }
    }

    private func check() {
        busy = true
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(750))
            guard let self else { return }
            let ids = self.flippedIDs
            guard ids.count == 2,
                  let i0 = self.cards.firstIndex(where: { $0.id == ids[0] }),
                  let i1 = self.cards.firstIndex(where: { $0.id == ids[1] }) else {
                self.flippedIDs = []; self.busy = false; return
            }
            if self.cards[i0].pairID == self.cards[i1].pairID {
                self.cards[i0].matched = true
                self.cards[i1].matched = true
                self.score   += 10
                self.matched += 1
                if self.matched == self.totalPairs { self.gameOver = true }
            } else {
                self.cards[i0].flipped = false
                self.cards[i1].flipped = false
                self.score = max(0, self.score - 1)
            }
            self.flippedIDs = []; self.busy = false
        }
    }
}

// MARK: - Single card face
private struct MemCardView: View {
    @EnvironmentObject private var appState: AppState
    let card: MemCard
    var body: some View {
        ZStack {
            if card.flipped || card.matched {
                if let img = UIImage(named: card.imgName) {
                    Image(uiImage: img).resizable().scaledToFill()
                } else {
                    appState.theme.background
                }
            } else {
                if let back = UIImage(named: "cardxxx") {
                    Image(uiImage: back).resizable().scaledToFill()
                } else {
                    Color(red: 0.70, green: 0.18, blue: 0.18)
                    Image(systemName: "questionmark")
                        .font(.custom("AlumniSans-Bold", size: 22))
                        .foregroundStyle(appState.theme.text)
                }
            }
        }
        .frame(width: 76, height: 76)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(card.matched ? appState.theme.accent : Color.clear, lineWidth: 3)
        )
        .opacity(card.matched ? 0.65 : 1)
        .rotation3DEffect(.degrees(card.flipped || card.matched ? 0 : 180), axis: (0, 1, 0))
        .animation(.easeInOut(duration: 0.3), value: card.flipped)
    }
}

// MARK: - WildRecallView
struct WildRecallView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var game = WildRecallGame()

    var body: some View {
        ZStack {
            appState.theme.background.ignoresSafeArea()
            VStack(spacing: 0) {
                // Score bar (sits below safeAreaInset header)
                HStack {
                    Text("Score: ")
                        .font(.custom("CreativeThoughts-Regular", size: 16))
                        .foregroundStyle(appState.theme.text)
                    Text("\(game.score)")
                        .font(.custom("AlumniSans-Bold", size: 18))
                        .foregroundStyle(appState.theme.accent)
                    Spacer()
                    Text("Pairs: \(game.matched)/\(game.totalPairs)")
                        .font(.system(size: 13))
                        .foregroundStyle(appState.theme.text.opacity(0.6))
                }
                .padding(.horizontal, 16).padding(.vertical, 8)

                // Grid — 4 columns for 6 pairs (12 cards)
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4),
                    spacing: 8
                ) {
                    ForEach(game.cards) { card in
                        MemCardView(card: card).environmentObject(appState)
                            .onTapGesture { game.tap(card) }
                    }
                }
                .padding(12)

                Spacer()

                Button { game.deal() } label: {
                    Text("New Game")
                        .font(.custom("AlumniSans-Bold", size: 18))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 30).padding(.vertical, 12)
                        .background(appState.theme.accent, in: RoundedRectangle(cornerRadius: 14))
                }
                .padding(.bottom, 20)
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                VStack(spacing: 0) {
                    HStack {
                        Button { appState.screen = .games } label: {
                            Image(systemName: "chevron.left")
                                .font(.custom("AlumniSans-Bold", size: 18))
                                .foregroundStyle(appState.theme.text)
                        }
                        Spacer()
                        Text("Wild Recall")
                            .font(.custom("GameOfSquids", size: 30))
                            .foregroundStyle(appState.theme.accent)
                        Spacer()
                        Button { appState.screen = .home } label: {
                            Image(systemName: "house.fill").foregroundStyle(appState.theme.text)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background {
                        Rectangle().fill(.regularMaterial).ignoresSafeArea(edges: .top)
                    }
                    Divider()
                }
            }
        }
        .overlay {
            if game.gameOver { winOverlay }
        }
        .onChange(of: game.gameOver) { _, over in
            if over { appState.saveMemoryScore(game.score) }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var winOverlay: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 18) {
                Text("🎉 Congratulations!")
                    .font(.custom("AlumniSans-Bold", size: 28))
                    .foregroundStyle(appState.theme.text)
                Text("Score: \(game.score)")
                    .font(.custom("AlumniSans-Bold", size: 24))
                    .foregroundStyle(appState.theme.accent)
                HStack(spacing: 14) {
                    Button { game.deal() } label: {
                        Text("Play Again")
                            .font(.custom("AlumniSans-Bold", size: 18))
                            .foregroundStyle(appState.theme.text)
                            .padding(.horizontal, 20).padding(.vertical, 12)
                            .background(appState.theme.accent, in: RoundedRectangle(cornerRadius: 12))
                    }
                    Button { appState.screen = .games } label: {
                        Text("Games")
                            .font(.custom("AlumniSans-Bold", size: 18))
                            .foregroundStyle(appState.theme.text)
                            .padding(.horizontal, 20).padding(.vertical, 12)
                            .background(Color.gray, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .padding(32)
            .background(
                appState.theme == .dark
                    ? Color(white: 0.12).opacity(0.95)
                    : appState.theme.background.opacity(0.95),
                in: RoundedRectangle(cornerRadius: 22)
            )
        }
    }
}
