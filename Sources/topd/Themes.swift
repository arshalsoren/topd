import AppKit
import SwiftUI
import TopdCore

/// Colors for the app chrome. Charts never use these: they keep the validated data palette in every theme.
struct ThemeColors {
    let background: Color
    let group: Color
    let separator: Color
    let text: Color
    let accent: Color
    /// Secondary text: the theme's text blended toward its background (about 78 percent text).
    let secondary: Color
    /// Tertiary text and placeholders: about 55 percent text.
    let tertiary: Color
}

extension AppTheme {
    var title: String {
        switch self {
        case .glass: return "Default"
        case .system: return "System"
        case .dracula: return "Dracula"
        case .nord: return "Nord"
        case .oneDark: return "One Dark"
        case .gitHubLight: return "GitHub Light"
        case .ayuLight: return "Ayu Light"
        case .gruvboxLight: return "Gruvbox Light"
        case .synthwave: return "Synthwave"
        case .ember: return "Ember"
        case .slate: return "Slate"
        case .ocean: return "Ocean"
        }
    }

    /// The window appearance the popover is drawn in. Light themes force light, dark themes force dark,
    /// and the default and match-system themes follow the system.
    var appearance: NSAppearance? {
        if self == .glass || self == .system { return nil }
        return NSAppearance(named: isDark ? .darkAqua : .aqua)
    }

    /// nil for the default translucent glass. Every other theme sets its own colors.
    /// Match system uses the system's semantic colors, so it changes with macOS light and dark.
    var colors: ThemeColors? {
        switch self {
        case .glass:
            return nil
        case .system:
            return ThemeColors(
                background: Color(nsColor: .windowBackgroundColor),
                group: Color(nsColor: .controlBackgroundColor),
                separator: Color(nsColor: .separatorColor),
                text: Color(nsColor: .labelColor),
                accent: Color(nsColor: .controlAccentColor),
                secondary: Color(nsColor: .secondaryLabelColor),
                tertiary: Color(nsColor: .tertiaryLabelColor)
            )
        // Dark
        case .dracula:
            return palette(bg: 0x282A36, group: 0x343746, separator: 0x44475A, text: 0xF8F8F2, accent: 0xBD93F9)
        case .nord:
            return palette(bg: 0x2E3440, group: 0x3B4252, separator: 0x4C566A, text: 0xECEFF4, accent: 0x88C0D0)
        case .oneDark:
            return palette(bg: 0x282C34, group: 0x353B45, separator: 0x3E4451, text: 0xABB2BF, accent: 0x61AFEF, secondaryAmount: 0.90, tertiaryAmount: 0.66)
        // Light
        case .gitHubLight:
            return palette(bg: 0xFFFFFF, group: 0xF6F8FA, separator: 0xD0D7DE, text: 0x24292F, accent: 0x0969DA)
        case .ayuLight:
            return palette(bg: 0xFAFAFA, group: 0xF0F1F3, separator: 0xD9D8D7, text: 0x5C6166, accent: 0x1F73B8, secondaryAmount: 0.92, tertiaryAmount: 0.73)
        case .gruvboxLight:
            return palette(bg: 0xFBF1C7, group: 0xF4E8C1, separator: 0xD5C4A1, text: 0x3C3836, accent: 0x076678, tertiaryAmount: 0.59)
        // Fun
        case .synthwave:
            return palette(bg: 0x262335, group: 0x332B4A, separator: 0x4A3F6B, text: 0xF0E6FF, accent: 0xFF7EDB)
        case .ember:
            return palette(bg: 0x1E1414, group: 0x2B1C1C, separator: 0x4A2C2C, text: 0xF5E6E3, accent: 0xFF5A4E)
        case .slate:
            return palette(bg: 0x1C1E22, group: 0x26292F, separator: 0x3B4048, text: 0xE4E7EB, accent: 0x9AA7B5)
        case .ocean:
            return palette(bg: 0x0C1B2A, group: 0x12283D, separator: 0x1E4062, text: 0xD6EAFF, accent: 0x3FA9F5)
        }
    }

    /// Three colors that stand for the theme in the chooser: background, accent, and text.
    var swatch: [Color] {
        switch self {
        case .glass:
            return [hex(0x2B2B2F), hex(0x0A84FF), hex(0xFFFFFF)]
        case .system:
            return [Color(nsColor: .windowBackgroundColor), Color(nsColor: .controlAccentColor), Color(nsColor: .labelColor)]
        default:
            guard let colors else { return [] }
            return [colors.background, colors.accent, colors.text]
        }
    }

    /// `secondaryAmount` and `tertiaryAmount` are the share of text color kept. Each theme's amounts are the
    /// smallest that meet 4.5:1 (secondary) and 3:1 (tertiary) against both its background and its group.
    private func palette(
        bg: UInt32, group: UInt32, separator: UInt32, text: UInt32, accent: UInt32,
        secondaryAmount: CGFloat = 0.78, tertiaryAmount: CGFloat = 0.55
    ) -> ThemeColors {
        ThemeColors(
            background: hex(bg), group: hex(group), separator: hex(separator), text: hex(text), accent: hex(accent),
            secondary: mix(text, bg, secondaryAmount), tertiary: mix(text, bg, tertiaryAmount)
        )
    }

    /// The text color moved toward the background by the given amount of text (1 is pure text).
    private func mix(_ text: UInt32, _ background: UInt32, _ amount: CGFloat) -> Color {
        let t = NSColor(hex: text), b = NSColor(hex: background)
        return Color(nsColor: t.blended(withFraction: 1 - amount, of: b) ?? t)
    }

    private func hex(_ value: UInt32) -> Color {
        Color(nsColor: NSColor(hex: value))
    }
}

/// Carries the active theme's colors down the view tree. nil means the default look.
private struct ThemeColorsKey: EnvironmentKey {
    static let defaultValue: ThemeColors? = nil
}

extension EnvironmentValues {
    var themeColors: ThemeColors? {
        get { self[ThemeColorsKey.self] }
        set { self[ThemeColorsKey.self] = newValue }
    }
}

/// Text that is secondary or tertiary in the current theme. Falls back to the system colors for the default look.
enum ThemedTextLevel {
    case secondary, tertiary
}

private struct ThemedTextStyle: ViewModifier {
    let level: ThemedTextLevel
    @Environment(\.themeColors) private var theme

    func body(content: Content) -> some View {
        switch level {
        case .secondary:
            content.foregroundStyle(theme?.secondary ?? Color.secondary)
        case .tertiary:
            content.foregroundStyle(theme?.tertiary ?? Color(nsColor: .tertiaryLabelColor))
        }
    }
}

extension View {
    func themedSecondary() -> some View {
        modifier(ThemedTextStyle(level: .secondary))
    }

    func themedTertiary() -> some View {
        modifier(ThemedTextStyle(level: .tertiary))
    }
}
