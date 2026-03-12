import SwiftUI

struct MemoryInfoView: View {
    @EnvironmentObject private var appState: AppState
    @State private var skip = false

    private let facts: [(String, String)] = [
        ("a1", "Cheetahs are harmed by habitat fragmentation and illegal wildlife tourism."),
        ("a2", "Elephants face stress and conflict when tourism damages natural habitats."),
        ("a3", "Giraffes are affected when travel activity disrupts feeding and breeding patterns."),
        ("a4", "Hippos are threatened by polluted waterways and habitat disturbance."),
        ("a5", "Gorillas are vulnerable to habitat pressure from irresponsible tours."),
        ("a6", "Lions are impacted by habitat loss, poaching pressure, and disruption."),
        ("a7", "Rhinos face rising poaching risk where tourism is unmanaged."),
        ("a8", "Sea turtles suffer from litter, light pollution, and nesting disruption."),
    ]

    var body: some View {
        ZStack {
            appState.theme.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    backBtn { appState.screen = .games }
                        .padding(.top, 8)

                    Text("Wild Recall")
                        .font(.custom("GameOfSquids-1GMVL", size: 36))
                        .foregroundStyle(appState.theme.accent)

                    Text("While traveling unsustainably across the world, many animals face severe consequences. Learn and then play.")
                        .font(.custom("AlumniSans-VariableFont_wght", size: 18))
                        .foregroundStyle(appState.theme.text)

                    ForEach(facts, id: \.0) { item in
                        HStack(alignment: .top, spacing: 10) {
                            if let img = UIImage(named: item.0) {
                                Image(uiImage: img).resizable().scaledToFill()
                                    .frame(width: 44, height: 44)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            Text(item.1)
                                .font(.custom("AlumniSans-VariableFont_wght", size: 15))
                                .foregroundStyle(appState.theme.text)
                        }
                        .padding(10)
                        .background(appState.theme.cardBackground, in: RoundedRectangle(cornerRadius: 12))
                    }

                    Toggle("Don't show this again", isOn: $skip)
                        .font(.custom("AlumniSans-Bold", size: 14))
                        .foregroundStyle(appState.theme.text)

                    Button {
                        appState.setSkipMemoryInfo(skip)
                        appState.screen = .wildRecall
                    } label: {
                        Text("Continue")
                            .font(.custom("AlumniSans-Bold", size: 20))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(appState.theme.accent, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.top, 4)
                }
                .padding(18)
                .padding(.bottom, 24)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

struct GamesView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ZStack {
            appState.theme.background.ignoresSafeArea()
            ScrollView {
                    VStack(spacing: 18) {
                        Text("Learn eco-facts while having fun!")
                            .font(.custom("CreativeThoughts-Regular", size: 14)).foregroundStyle(appState.theme.text.opacity(0.75))
                            .padding(.top, 10)

                        gameCard(title: "Wild Recall",
                                 sub: "Match animal pairs — eco memory game",
                                 bannerImage: "a1",
                                 color: Color(red: 0.70, green: 0.18, blue: 0.18),
                                 score: appState.memoryScore) {
                            appState.screen = appState.skipMemoryInfo ? .wildRecall : .memoryInfo
                        }

                        gameCard(title: "Reef Rescuers",
                                 sub: "Catch falling trash before it hits the ocean",
                                 bannerImage: "oceangameicon",
                                 color: Color(red: 0.04, green: 0.32, blue: 0.70),
                                 score: appState.oceanScore) {
                            appState.screen = appState.skipOceanInfo ? .ocean : .oceanInfo
                        }

                        gameCard(title: "Eco Trivia",
                                 sub: "5-round quiz on sustainable travel",
                                 bannerImage: "Europetrafic",
                                 color: Color(red: 0.08, green: 0.42, blue: 0.14),
                                 score: appState.triviaScore) {
                            appState.screen = .trivia
                        }
                    }
                    .padding(16)
                    .padding(.bottom, 30)
                }
                
            .safeAreaInset(edge: .top, spacing: 0) {
                navBar(title: "Games", back: .home)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    @ViewBuilder
    private func gameCard(title: String, sub: String, bannerImage: String,
                          color: Color, score: Int, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                // Banner
                Group {
                    if let img = UIImage(named: bannerImage) {
                        Image(uiImage: img).resizable().scaledToFill()
                            .frame(height: 110).clipped()
                    } else {
                        color.opacity(0.25).frame(height: 110)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title).font(.custom("AlumniSans-Bold", size: 20)).foregroundStyle(color)
                        Text(sub).font(.system(size: 13)).foregroundStyle(appState.theme.text.opacity(0.7))
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Best").font(.system(size: 11)).foregroundStyle(appState.theme.text.opacity(0.6))
                        Text("\(score)").font(.custom("AlumniSans-Bold", size: 20)).foregroundStyle(color)
                    }
                }
                .padding(14)
            }
            .background(appState.theme.cardBackground, in: RoundedRectangle(cornerRadius: 16))
            .shadow(color: color.opacity(0.14), radius: 8, x: 0, y: 4)
        }
    }
}
