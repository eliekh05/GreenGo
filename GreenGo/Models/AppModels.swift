import SwiftUI

// MARK: - Navigation
enum Screen: Hashable {
    case splash
    case home
    case map
    case mapInfo
    case functionality
    case translator
    case pedometer
    case games
    case memoryInfo
    case wildRecall
    case oceanInfo
    case ocean
    case trivia
    case triviaScore(Int)
    case settings
    case about
    case contact
    case preferences
}

// MARK: - App Theme
enum AppTheme: String, CaseIterable {
    case mint   = "mint"
    case light  = "light"
    case dark   = "dark"
    case nature = "nature"

    var displayName: String {
        switch self {
        case .mint:   return "Mint"
        case .light:  return "Light"
        case .dark:   return "Dark"
        case .nature: return "Nature"
        }
    }

    var background: Color {
        switch self {
        case .mint:   return Color(red: 0.82, green: 1.0, blue: 0.97)
        case .light:  return .white
        case .dark:   return Color(red: 0.10, green: 0.12, blue: 0.15)
        case .nature: return Color(red: 0.85, green: 0.93, blue: 0.83)
        }
    }

    var text: Color {
        self == .dark ? .white : Color(red: 0.20, green: 0.20, blue: 0.20)
    }

    var accent: Color {
        switch self {
        case .dark:   return Color(red: 0.40, green: 0.90, blue: 0.50)
        case .nature: return Color(red: 0.15, green: 0.55, blue: 0.25)
        default:      return Color(red: 0.12, green: 0.58, blue: 0.08)
        }
    }

    // Dot shown in Settings > Appearance.
    var appearanceDot: Color {
        switch self {
        case .mint:   return Color(red: 0.10, green: 0.74, blue: 0.58)
        case .light:  return Color(red: 0.75, green: 0.75, blue: 0.75)
        case .dark:   return Color(red: 0.24, green: 0.30, blue: 0.40)
        case .nature: return Color(red: 0.34, green: 0.55, blue: 0.20)
        }
    }

    var cardBackground: Color {
        self == .dark ? Color(white: 0.14) : .white
    }

    var inputBackground: Color {
        self == .dark ? Color(white: 0.12) : .white
    }

    var mutedText: Color {
        text.opacity(0.7)
    }
}
