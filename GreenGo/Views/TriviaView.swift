import SwiftUI
import UIKit

// MARK: - TriviaView
// Questions are shuffled each game; answers within each question are also shuffled
// so the correct answer is never always in position 0 (real-trivia feel).
struct TriviaView: View {
    @EnvironmentObject private var appState: AppState

    // Shuffled question order + shuffled answer order, rebuilt on each game
    @State private var questions:    [TriviaQuestion] = []
    @State private var answerOrders: [[Int]]          = []   // per-question shuffled index arrays
    @State private var qIndex        = 0
    @State private var score         = 0
    @State private var chosen: Int?  = nil   // index into the SHUFFLED answers array
    @State private var showFeedback  = false

    private var q: TriviaQuestion { questions.isEmpty ? allTriviaQuestions[0] : questions[qIndex] }
    // Maps shuffled answer position → original answer index (to find correctIndex)
    private var currentOrder: [Int]  { answerOrders.isEmpty ? Array(0..<q.answers.count) : answerOrders[qIndex] }
    // The shuffled position of the correct answer for the current question
    private var shuffledCorrectIdx: Int {
        currentOrder.firstIndex(of: q.correctIndex) ?? q.correctIndex
    }

    var body: some View {
        ZStack {
            appState.theme.background.ignoresSafeArea()
            ScrollView {
                    VStack(spacing: 16) {
                        // Question card
                        Text(q.question)
                            .font(.custom("AlumniSans-Bold", size: 16))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(appState.theme.text)
                            .padding(16)
                            .frame(maxWidth: .infinity)
                            .background(appState.theme.background.opacity(appState.theme == .light ? 0.6 : 0.12),
                                        in: RoundedRectangle(cornerRadius: 14))

                        // Shuffled answer cards
                        ForEach(Array(currentOrder.enumerated()), id: \.offset) { shuffledIdx, originalIdx in
                            answerCard(
                                ans: q.answers[originalIdx],
                                shuffledIdx: shuffledIdx
                            )
                        }

                        // Explanation after tap
                        if showFeedback, let c = chosen {
                            let isCorrect = (c == shuffledCorrectIdx)
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundStyle(isCorrect ? .green : .red)
                                    Text(isCorrect ? "Correct!" : "Incorrect")
                                        .font(.custom("AlumniSans-Bold", size: 16))
                                        .foregroundStyle(isCorrect ? .green : .red)
                                }
                                // Show explanation for whichever answer was tapped
                                Text(q.answers[currentOrder[c]].explanation)
                                    .font(.custom("CreativeThoughts-Regular", size: 14))
                                    .foregroundStyle(appState.theme.text.opacity(0.9))
                            }
                            .padding(14)
                            .background(appState.theme.background.opacity(0.4),
                                        in: RoundedRectangle(cornerRadius: 12))

                            Button { advance() } label: {
                                Text(qIndex < questions.count - 1 ? "Next Question" : "See Results")
                                    .font(.custom("AlumniSans-Bold", size: 18))
                                    .foregroundStyle(.black)
                                    .frame(maxWidth: .infinity).padding()
                                    .background(appState.theme.accent, in: RoundedRectangle(cornerRadius: 14))
                            }
                        }
                    }
                    .padding(16)
                    .padding(.bottom, 30)
                }
            .safeAreaInset(edge: .top, spacing: 0) {
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Button { appState.screen = .games } label: {
                            Image(systemName: "chevron.left")
                                .font(.custom("AlumniSans-Bold", size: 18))
                                .foregroundStyle(appState.theme.text)
                        }
                        Spacer()
                        Text("Eco Trivia")
                            .font(.custom("AlumniSans-Bold", size: 22))
                            .foregroundStyle(appState.theme.text)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 1) {
                            Text("Score").font(.system(size: 10)).foregroundStyle(appState.theme.text.opacity(0.8))
                            Text("\(score)").font(.custom("AlumniSans-Bold", size: 20))
                                .foregroundStyle(appState.theme.accent)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background {
                        Rectangle().fill(.regularMaterial).ignoresSafeArea(edges: .top)
                    }
                    // Progress dots
                    HStack(spacing: 6) {
                        ForEach(0..<questions.count, id: \.self) { i in
                            Circle()
                                .fill(i < qIndex ? appState.theme.accent
                                      : (i == qIndex ? appState.theme.text
                                         : appState.theme.text.opacity(0.35)))
                                .frame(width: i == qIndex ? 10 : 7,
                                       height: i == qIndex ? 10 : 7)
                        }
                    }
                    .padding(.vertical, 8)
                    .background(appState.theme.background.opacity(0.9))
                    Divider()
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            if questions.isEmpty { buildGame() }
            lockLandscape()
        }
        .onDisappear { unlockAll() }
    }

    // MARK: - Game setup
    private func buildGame() {
        let shuffledQs = allTriviaQuestions.shuffled()
        var orders: [[Int]] = []
        for q in shuffledQs {
            orders.append(Array(0..<q.answers.count).shuffled())
        }
        questions    = shuffledQs
        answerOrders = orders
        qIndex       = 0
        score        = 0
        chosen       = nil
        showFeedback = false
    }

    // MARK: - Answer card
    @ViewBuilder
    private func answerCard(ans: TriviaAnswer, shuffledIdx: Int) -> some View {
        let isChosen  = chosen == shuffledIdx
        let isCorrect = (shuffledIdx == shuffledCorrectIdx)
        let tint: Color = {
            guard showFeedback else { return appState.theme.text }
            if isChosen  { return isCorrect ? .green : .red }
            if isCorrect { return .green }
            return appState.theme.text.opacity(0.5)
        }()

        Button {
            guard !showFeedback else { return }
            chosen       = shuffledIdx
            showFeedback = true
            if isCorrect { score += 10 }
        } label: {
            HStack(spacing: 12) {
                Group {
                    if let img = UIImage(named: ans.imageName) {
                        Image(uiImage: img).resizable().scaledToFill()
                            .frame(width: 56, height: 56).clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        RoundedRectangle(cornerRadius: 8).fill(tint.opacity(0.3))
                            .frame(width: 56, height: 56)
                    }
                }
                Text(ans.text)
                    .font(.custom("AlumniSans-Bold", size: 15))
                    .foregroundStyle(appState.theme.text)
                    .multilineTextAlignment(.leading)
                Spacer()
                if showFeedback {
                    Image(systemName: isCorrect ? "checkmark.circle.fill"
                          : (isChosen ? "xmark.circle.fill" : ""))
                        .foregroundStyle(isCorrect ? .green : .red)
                        .font(.custom("CreativeThoughts-Regular", size: 20))
                }
            }
            .padding(12)
            .background(
                isChosen ? tint.opacity(0.35) : appState.theme.background.opacity(0.12),
                in: RoundedRectangle(cornerRadius: 12)
            )
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(tint, lineWidth: isChosen ? 2 : 0))
        }
        .disabled(showFeedback)
    }

    // MARK: - Advance
    private func advance() {
        if qIndex < questions.count - 1 {
            qIndex      += 1
            chosen       = nil
            showFeedback = false
        } else {
            appState.saveTriviaScore(score)
            appState.screen = .triviaScore(score)
        }
    }

    // MARK: - Orientation (iOS 16+ public API, no private KVO)
    private func lockLandscape() {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first else { return }
        scene.requestGeometryUpdate(
            UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: .landscape)
        ) { _ in }
    }
    private func unlockAll() {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first else { return }
        scene.requestGeometryUpdate(
            UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: .all)
        ) { _ in }
    }
}

// MARK: - TriviaScoreView
struct TriviaScoreView: View {
    @EnvironmentObject private var appState: AppState
    let score: Int
    private let max   = allTriviaQuestions.count * 10
    private let green = Color(red: 0.08, green: 0.42, blue: 0.14)

    var body: some View {
        ZStack {
            green.ignoresSafeArea()
            VStack(spacing: 28) {
                Spacer()
                if let img = UIImage(named: "GreenGologocopy") {
                    Image(uiImage: img).resizable().scaledToFit()
                        .frame(width: 90, height: 90)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                }
                Text("Quiz Complete!")
                    .font(.custom("AlumniSans-Bold", size: 34)).foregroundStyle(.white)
                VStack(spacing: 6) {
                    Text("Your Score")
                        .font(.custom("CreativeThoughts-Regular", size: 16)).foregroundStyle(.white.opacity(0.8))
                    Text("\(score) / \(max)")
                        .font(.custom("AlumniSans-Bold", size: 52))
                        .foregroundStyle(Color(red: 0.97, green: 0.91, blue: 0.35))
                }
                .padding(20)
                .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 18))

                Text(score == max ? "Perfect score! 🌍" :
                     score >= max / 2 ? "Great job! Keep learning! 🌿" :
                     "Nice try! Play again to improve 💪")
                    .font(.custom("CreativeThoughts-Regular", size: 16))
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)

                Spacer()

                VStack(spacing: 12) {
                    Button { appState.screen = .trivia } label: {
                        Text("Play Again")
                            .font(.custom("AlumniSans-Bold", size: 20)).foregroundStyle(.black)
                            .frame(maxWidth: .infinity).padding()
                            .background(Color(red: 0.97, green: 0.91, blue: 0.35),
                                        in: RoundedRectangle(cornerRadius: 14))
                    }
                    Button { appState.screen = .games } label: {
                        Text("Games")
                            .font(.custom("AlumniSans-Bold", size: 18)).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding()
                            .background(Color.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 14))
                    }
                    Button { appState.screen = .home } label: {
                        Text("Home")
                            .font(.custom("CreativeThoughts-Regular", size: 16))
                            .foregroundStyle(.white.opacity(0.75))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
            .padding(.horizontal, 24)
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}
