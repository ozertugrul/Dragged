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

    // Outer ambient frosted glass ring fill
    public var ringFill: Color {
        switch self {
        case .tangerine:
            return Color(red: 0.96, green: 0.90, blue: 0.80).opacity(0.85)
        case .cyberNeon:
            return Color(red: 0.05, green: 0.08, blue: 0.16).opacity(0.88)
        case .emerald:
            return Color(red: 0.90, green: 0.96, blue: 0.92).opacity(0.88)
        case .obsidian:
            return Color(red: 0.08, green: 0.08, blue: 0.10).opacity(0.92)
        case .sunsetRose:
            return Color(red: 0.98, green: 0.90, blue: 0.93).opacity(0.88)
        }
    }

    // Outer ring specular rim stroke
    public var ringStrokeGradient: [Color] {
        switch self {
        case .tangerine:
            return [Color.orange.opacity(0.45), Color.white.opacity(0.4)]
        case .cyberNeon:
            return [Color(red: 0.0, green: 0.95, blue: 1.0).opacity(0.6), Color(red: 0.6, green: 0.2, blue: 1.0).opacity(0.4)]
        case .emerald:
            return [Color(red: 0.06, green: 0.75, blue: 0.52).opacity(0.55), Color.white.opacity(0.4)]
        case .obsidian:
            return [Color.white.opacity(0.45), Color.gray.opacity(0.2)]
        case .sunsetRose:
            return [Color(red: 0.98, green: 0.25, blue: 0.45).opacity(0.55), Color.white.opacity(0.4)]
        }
    }

    // Inner ring border
    public var innerRingBorder: Color {
        switch self {
        case .tangerine:
            return Color.orange.opacity(0.35)
        case .cyberNeon:
            return Color(red: 0.0, green: 0.95, blue: 1.0).opacity(0.4)
        case .emerald:
            return Color(red: 0.06, green: 0.75, blue: 0.52).opacity(0.4)
        case .obsidian:
            return Color.white.opacity(0.25)
        case .sunsetRose:
            return Color(red: 0.98, green: 0.25, blue: 0.45).opacity(0.4)
        }
    }

    // Petal default background
    public var petalDefaultFill: Color {
        switch self {
        case .tangerine:
            return Color(red: 1.0, green: 0.96, blue: 0.89).opacity(0.94)
        case .cyberNeon:
            return Color(red: 0.11, green: 0.15, blue: 0.24).opacity(0.92)
        case .emerald:
            return Color(red: 0.95, green: 0.99, blue: 0.96).opacity(0.94)
        case .obsidian:
            return Color(red: 0.16, green: 0.16, blue: 0.19).opacity(0.94)
        case .sunsetRose:
            return Color(red: 1.0, green: 0.95, blue: 0.96).opacity(0.94)
        }
    }

    // Petal default text color
    public var petalTextColor: Color {
        switch self {
        case .tangerine:
            return Color(red: 0.12, green: 0.12, blue: 0.12)
        case .cyberNeon:
            return Color(red: 0.92, green: 0.96, blue: 1.0)
        case .emerald:
            return Color(red: 0.08, green: 0.22, blue: 0.14)
        case .obsidian:
            return Color(red: 0.95, green: 0.95, blue: 0.95)
        case .sunsetRose:
            return Color(red: 0.25, green: 0.08, blue: 0.14)
        }
    }

    // Active / Hovered blooming gradient
    public var activeGradient: [Color] {
        switch self {
        case .tangerine:
            return [Color(red: 0.98, green: 0.42, blue: 0.12), Color(red: 0.88, green: 0.26, blue: 0.04)]
        case .cyberNeon:
            return [Color(red: 0.0, green: 0.95, blue: 1.0), Color(red: 0.31, green: 0.45, blue: 0.98)]
        case .emerald:
            return [Color(red: 0.08, green: 0.78, blue: 0.54), Color(red: 0.03, green: 0.55, blue: 0.38)]
        case .obsidian:
            return [Color(red: 0.45, green: 0.48, blue: 0.55), Color(red: 0.20, green: 0.22, blue: 0.28)]
        case .sunsetRose:
            return [Color(red: 0.98, green: 0.25, blue: 0.42), Color(red: 0.78, green: 0.08, blue: 0.28)]
        }
    }

    // Shadow glow color when hovered
    public var hoverGlowColor: Color {
        switch self {
        case .tangerine:
            return Color.orange.opacity(0.65)
        case .cyberNeon:
            return Color(red: 0.0, green: 0.95, blue: 1.0).opacity(0.7)
        case .emerald:
            return Color(red: 0.08, green: 0.78, blue: 0.54).opacity(0.65)
        case .obsidian:
            return Color.white.opacity(0.35)
        case .sunsetRose:
            return Color(red: 0.98, green: 0.25, blue: 0.42).opacity(0.65)
        }
    }

    // Header background & border
    public var headerBackground: Color {
        switch self {
        case .tangerine:
            return Color(red: 1.0, green: 0.98, blue: 0.94).opacity(0.95)
        case .cyberNeon:
            return Color(red: 0.08, green: 0.12, blue: 0.20).opacity(0.95)
        case .emerald:
            return Color(red: 0.94, green: 0.99, blue: 0.96).opacity(0.95)
        case .obsidian:
            return Color(red: 0.12, green: 0.12, blue: 0.15).opacity(0.95)
        case .sunsetRose:
            return Color(red: 1.0, green: 0.96, blue: 0.97).opacity(0.95)
        }
    }

    public var headerBorder: Color {
        switch self {
        case .tangerine:
            return Color(red: 0.98, green: 0.58, blue: 0.16).opacity(0.4)
        case .cyberNeon:
            return Color(red: 0.0, green: 0.95, blue: 1.0).opacity(0.4)
        case .emerald:
            return Color(red: 0.08, green: 0.78, blue: 0.54).opacity(0.4)
        case .obsidian:
            return Color.white.opacity(0.3)
        case .sunsetRose:
            return Color(red: 0.98, green: 0.25, blue: 0.42).opacity(0.4)
        }
    }

    public var headerTextColor: Color {
        switch self {
        case .tangerine:
            return Color(red: 0.15, green: 0.10, blue: 0.05)
        case .cyberNeon:
            return Color(red: 0.9, green: 0.95, blue: 1.0)
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
            return Color(red: 0.98, green: 0.42, blue: 0.12)
        case .cyberNeon:
            return Color(red: 0.0, green: 0.95, blue: 1.0)
        case .emerald:
            return Color(red: 0.08, green: 0.78, blue: 0.54)
        case .obsidian:
            return Color.white
        case .sunsetRose:
            return Color(red: 0.98, green: 0.25, blue: 0.42)
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
