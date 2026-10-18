import SwiftUI
import AppKit

public enum AppTheme: String, CaseIterable, Identifiable {
    case tangerine = "tangerine"
    case cyberNeon = "cyber_neon"
    case emerald = "emerald"
    case obsidian = "obsidian"
    case sunsetRose = "sunset_rose"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .tangerine: return "Liquid Tangerine"
        case .cyberNeon: return "Cyber Neon"
        case .emerald: return "Emerald Forest"
        case .obsidian: return "Midnight Obsidian"
        case .sunsetRose: return "Sunset Rose"
        }
    }

    public var isDark: Bool {
        switch self {
        case .cyberNeon, .obsidian: return true
        default: return false
        }
    }

    // Outer ambient frosted glass ring tint (layered over .ultraThinMaterial)
    public var ringFill: Color {
        switch self {
        case .tangerine:
            return Color(red: 1.0, green: 0.92, blue: 0.82).opacity(0.35)
        case .cyberNeon:
            return Color(red: 0.04, green: 0.08, blue: 0.18).opacity(0.40)
        case .emerald:
            return Color(red: 0.88, green: 0.98, blue: 0.92).opacity(0.35)
        case .obsidian:
            return Color(red: 0.04, green: 0.04, blue: 0.06).opacity(0.55)
        case .sunsetRose:
            return Color(red: 1.0, green: 0.88, blue: 0.93).opacity(0.35)
        }
    }

    // Outer ring specular rim stroke
    public var ringStrokeGradient: [Color] {
        switch self {
        case .tangerine:
            return [Color.white.opacity(0.85), Color.orange.opacity(0.55), Color.white.opacity(0.20), Color.orange.opacity(0.35)]
        case .cyberNeon:
            return [Color(red: 0.0, green: 0.95, blue: 1.0).opacity(0.85), Color(red: 0.6, green: 0.2, blue: 1.0).opacity(0.5), Color.white.opacity(0.3)]
        case .emerald:
            return [Color.white.opacity(0.85), Color(red: 0.06, green: 0.75, blue: 0.52).opacity(0.65), Color.white.opacity(0.25)]
        case .obsidian:
            return [Color.white.opacity(0.70), Color.white.opacity(0.20), Color.gray.opacity(0.15), Color.white.opacity(0.35)]
        case .sunsetRose:
            return [Color.white.opacity(0.85), Color(red: 0.98, green: 0.25, blue: 0.45).opacity(0.65), Color.white.opacity(0.25)]
        }
    }

    // Inner ring border
    public var innerRingBorder: Color {
        switch self {
        case .tangerine:
            return Color.orange.opacity(0.30)
        case .cyberNeon:
            return Color(red: 0.0, green: 0.95, blue: 1.0).opacity(0.35)
        case .emerald:
            return Color(red: 0.06, green: 0.75, blue: 0.52).opacity(0.35)
        case .obsidian:
            return Color.white.opacity(0.20)
        case .sunsetRose:
            return Color(red: 0.98, green: 0.25, blue: 0.45).opacity(0.35)
        }
    }

    // Petal default background (layered over .ultraThinMaterial)
    public var petalDefaultFill: Color {
        switch self {
        case .tangerine:
            return Color.white.opacity(0.40)
        case .cyberNeon:
            return Color(red: 0.12, green: 0.18, blue: 0.30).opacity(0.45)
        case .emerald:
            return Color.white.opacity(0.40)
        case .obsidian:
            return Color(red: 0.16, green: 0.16, blue: 0.20).opacity(0.50)
        case .sunsetRose:
            return Color.white.opacity(0.40)
        }
    }

    // Petal default text color
    public var petalTextColor: Color {
        switch self {
        case .tangerine:
            return Color(red: 0.10, green: 0.10, blue: 0.10)
        case .cyberNeon:
            return Color(red: 0.92, green: 0.97, blue: 1.0)
        case .emerald:
            return Color(red: 0.06, green: 0.22, blue: 0.14)
        case .obsidian:
            return Color(red: 0.95, green: 0.95, blue: 0.95)
        case .sunsetRose:
            return Color(red: 0.25, green: 0.06, blue: 0.12)
        }
    }

    // Active / Hovered blooming gradient
    public var activeGradient: [Color] {
        switch self {
        case .tangerine:
            return [Color(red: 0.99, green: 0.45, blue: 0.12), Color(red: 0.88, green: 0.26, blue: 0.04)]
        case .cyberNeon:
            return [Color(red: 0.0, green: 0.95, blue: 1.0), Color(red: 0.31, green: 0.45, blue: 0.98)]
        case .emerald:
            return [Color(red: 0.08, green: 0.80, blue: 0.54), Color(red: 0.02, green: 0.56, blue: 0.38)]
        case .obsidian:
            return [Color(red: 0.50, green: 0.52, blue: 0.60), Color(red: 0.22, green: 0.24, blue: 0.30)]
        case .sunsetRose:
            return [Color(red: 0.99, green: 0.25, blue: 0.45), Color(red: 0.80, green: 0.08, blue: 0.30)]
        }
    }

    // Shadow glow color when hovered
    public var hoverGlowColor: Color {
        switch self {
        case .tangerine:
            return Color.orange.opacity(0.70)
        case .cyberNeon:
            return Color(red: 0.0, green: 0.95, blue: 1.0).opacity(0.75)
        case .emerald:
            return Color(red: 0.08, green: 0.80, blue: 0.54).opacity(0.70)
        case .obsidian:
            return Color.white.opacity(0.40)
        case .sunsetRose:
            return Color(red: 0.99, green: 0.25, blue: 0.45).opacity(0.70)
        }
    }

    // Header background & border (layered over .ultraThinMaterial)
    public var headerBackground: Color {
        switch self {
        case .tangerine:
            return Color.white.opacity(0.45)
        case .cyberNeon:
            return Color(red: 0.06, green: 0.10, blue: 0.18).opacity(0.55)
        case .emerald:
            return Color.white.opacity(0.45)
        case .obsidian:
            return Color(red: 0.10, green: 0.10, blue: 0.13).opacity(0.60)
        case .sunsetRose:
            return Color.white.opacity(0.45)
        }
    }

    public var headerBorder: Color {
        switch self {
        case .tangerine:
            return Color.white.opacity(0.75)
        case .cyberNeon:
            return Color(red: 0.0, green: 0.95, blue: 1.0).opacity(0.55)
        case .emerald:
            return Color.white.opacity(0.75)
        case .obsidian:
            return Color.white.opacity(0.35)
        case .sunsetRose:
            return Color.white.opacity(0.75)
        }
    }

    public var headerTextColor: Color {
        switch self {
        case .tangerine:
            return Color(red: 0.15, green: 0.10, blue: 0.05)
        case .cyberNeon:
            return Color(red: 0.90, green: 0.96, blue: 1.0)
        case .emerald:
            return Color(red: 0.06, green: 0.20, blue: 0.12)
        case .obsidian:
            return Color.white
        case .sunsetRose:
            return Color(red: 0.25, green: 0.06, blue: 0.12)
        }
    }

    public var dotActiveColor: Color {
        switch self {
        case .tangerine:
            return Color(red: 0.99, green: 0.45, blue: 0.12)
        case .cyberNeon:
            return Color(red: 0.0, green: 0.95, blue: 1.0)
        case .emerald:
            return Color(red: 0.08, green: 0.80, blue: 0.54)
        case .obsidian:
            return Color.white
        case .sunsetRose:
            return Color(red: 0.99, green: 0.25, blue: 0.45)
        }
    }
}

public class ThemeManager: ObservableObject {
    public static let shared = ThemeManager()

    private let themeKey = "dragged_selected_theme"

    @Published public var currentTheme: AppTheme = .tangerine {
        didSet {
            UserDefaults.standard.set(currentTheme.rawValue, forKey: themeKey)
        }
    }

    private init() {
        if let saved = UserDefaults.standard.string(forKey: themeKey),
           let theme = AppTheme(rawValue: saved) {
            self.currentTheme = theme
        }
    }

    public func setTheme(_ theme: AppTheme) {
        self.currentTheme = theme
    }
}
