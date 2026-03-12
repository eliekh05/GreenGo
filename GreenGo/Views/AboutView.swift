import SwiftUI

struct AboutView: View {
    @EnvironmentObject private var appState: AppState

    private let sections: [(String, [String])] = [
        ("What is Green Go?", [
            "Green Go is an eco-friendly travel companion designed to help tourists make sustainable choices wherever they are in the world.",
            "The app provides interactive maps of eco-friendly accommodations, cycling routes, and nature sites across every continent.",
        ]),
        ("Our Mission", [
            "We believe travel should leave the world better than we found it.",
            "Green Go empowers travellers with tools, knowledge, and games that make sustainability fun and accessible.",
        ]),
        ("Features", [
            "🗺️ Eco Map — 150+ vetted eco-friendly locations worldwide",
            "🌐 Translator — Speak or type in 20+ languages",
            "🚶 Pedometer — Track steps, distance and time",
            "🎮 Games — Wild Recall, Reef Rescuers, Eco Trivia",
            "📖 Eco Tips — Learn while exploring",
        ]),
        ("Responsible Tourism", [
            "Support local businesses over large chains.",
            "Use public transportation or cycling whenever possible.",
            "Observe wildlife from a safe distance — never feed animals.",
            "Carry reusable items and avoid single-use plastics.",
            "Leave every place cleaner than you found it.",
        ]),
    ]

    var body: some View {
        ZStack {
            appState.theme.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 10) {
                        if let img = UIImage(named: "GreenGologocopy") {
                            Image(uiImage: img).resizable().scaledToFit()
                                .frame(width: 90, height: 90)
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                        }
                        HStack(spacing: 0) {
                            Text("Green").foregroundStyle(Color(red: 0.08, green: 0.52, blue: 0.10))
                            Text("Go").foregroundStyle(Color(red: 0.10, green: 0.38, blue: 0.82))
                        }
                        .font(.custom("YBDarkChocolateFudge", size: 36))
                        Text("Version 1.0")
                            .font(.system(size: 13)).foregroundStyle(appState.theme.mutedText)
                    }
                    .padding(.top, 20)

                    ForEach(sections, id: \.0) { section in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(section.0)
                                .font(.custom("AlumniSans-Bold", size: 18))
                                .foregroundStyle(Color(red: 0.08, green: 0.52, blue: 0.10))
                            ForEach(section.1, id: \.self) { line in
                                Text(line).font(.custom("CreativeThoughts-Regular", size: 14))
                                    .foregroundStyle(appState.theme.text)
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(appState.theme.cardBackground, in: RoundedRectangle(cornerRadius: 14))
                        .shadow(color: .black.opacity(0.05), radius: 4)
                    }

                    Spacer().frame(height: 30)
                }
                .padding(.horizontal, 16)
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                navBar(title: "About", back: .home)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}
