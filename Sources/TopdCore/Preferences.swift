import Foundation

public enum Card: String, CaseIterable, Sendable {
    case cpu, memory, gpu, storage, system, network
}

extension Card {
    /// The label shown with the card's icon.
    public var title: String {
        switch self {
        case .cpu: return "CPU"
        case .memory: return "Memory"
        case .gpu: return "GPU"
        case .storage: return "Storage"
        case .system: return "System"
        case .network: return "Network"
        }
    }
}

/// Color theme for the app chrome. Charts keep the validated data palette in every theme. The colors live in the app target.
/// Twelve themes in menu order: default, match system, three dark, three light, four fun.
/// The default keeps the raw value "system" so settings saved before this change still load.
public enum AppTheme: String, CaseIterable, Sendable {
    case glass = "system"
    /// Follows macOS: uses the dark or light theme chosen in Preferences. Stored as "followSystem".
    case system = "followSystem"
    case dracula, nord, oneDark
    case gitHubLight, ayuLight, gruvboxLight
    case synthwave, ember, slate, ocean

    public var isDark: Bool {
        switch self {
        case .dracula, .nord, .oneDark, .synthwave, .ember, .slate, .ocean: return true
        default: return false
        }
    }

    /// Themes that can be used for macOS dark mode, and for macOS light mode.
    public static let darkChoices: [AppTheme] = [.dracula, .nord, .oneDark, .synthwave, .ember, .slate, .ocean]
    public static let lightChoices: [AppTheme] = [.gitHubLight, .ayuLight, .gruvboxLight]
}

public enum ProcessSection: String, CaseIterable, Sendable {
    case topCPU, topMemory
}

/// Menu bar icon. The raw value is the SF Symbol name, or "topd" for the topd logo (drawn in the app).
public enum MenuIcon: String, CaseIterable, Sendable {
    case topd
    case gauge = "gauge.with.dots.needle.67percent"
    case waveform = "waveform.path.ecg"
    case chip = "cpu"
    case trend = "chart.line.uptrend.xyaxis"

    public var symbol: String { rawValue }

    /// The label shown in the Customize icon dropdown. Always lowercase letters and digits.
    public var title: String {
        switch self {
        case .topd: return "topd"
        case .gauge: return "gauge"
        case .waveform: return "waveform"
        case .chip: return "chip"
        case .trend: return "trend"
        }
    }
}

/// Settings with the spec's rules. At-a-glance is OFF by default; when ON it shows 1 to 3 cards, all of which must be ON.
/// Every mutation either applies fully or returns false and leaves the state unchanged.
public struct Preferences: Equatable, Sendable {
    public static let glanceRange = 1...3
    public static let defaultGlance: [Card] = [.cpu, .gpu, .memory]

    public private(set) var cards: Set<Card>
    public private(set) var sections: Set<ProcessSection>
    /// The chosen glance cards. Kept even while at-a-glance is OFF, so turning it back on restores the choice.
    public private(set) var glance: [Card]
    public private(set) var glanceEnabled: Bool
    public private(set) var menuIcon: MenuIcon
    /// The user's card order, for the popover grid and the Cards list. Always contains every card once.
    public private(set) var cardOrder: [Card]
    public private(set) var theme: AppTheme
    /// Theme used when the theme is System and macOS is in dark mode.
    public private(set) var systemDarkTheme: AppTheme
    /// Theme used when the theme is System and macOS is in light mode.
    public private(set) var systemLightTheme: AppTheme

    public init(
        cards: Set<Card> = Set(Card.allCases),
        sections: Set<ProcessSection> = Set(ProcessSection.allCases),
        glance: [Card] = Preferences.defaultGlance,
        glanceEnabled: Bool = false,
        menuIcon: MenuIcon = .topd,
        cardOrder: [Card] = Card.allCases,
        theme: AppTheme = .glass,
        systemDarkTheme: AppTheme = .dracula,
        systemLightTheme: AppTheme = .gitHubLight
    ) {
        self.cards = cards.isEmpty ? Set(Card.allCases) : cards
        self.sections = sections
        self.glanceEnabled = glanceEnabled
        self.menuIcon = menuIcon
        self.theme = theme
        self.systemDarkTheme = AppTheme.darkChoices.contains(systemDarkTheme) ? systemDarkTheme : .dracula
        self.systemLightTheme = AppTheme.lightChoices.contains(systemLightTheme) ? systemLightTheme : .gitHubLight

        // Keep the saved order for known cards, once each, then append any card the saved order lacks.
        var order: [Card] = []
        for card in cardOrder + Card.allCases where !order.contains(card) {
            order.append(card)
        }
        self.cardOrder = order

        var picked: [Card] = []
        for card in glance where self.cards.contains(card) && !picked.contains(card) {
            picked.append(card)
        }
        picked = Array(picked.prefix(Self.glanceRange.upperBound))
        self.glance = picked.isEmpty ? [Self.firstEnabled(in: self.cards)] : picked
    }

    /// Turning a card OFF removes it from the glance selection; if that empties it, the first ON card takes its place.
    @discardableResult
    public mutating func setCard(_ card: Card, enabled: Bool) -> Bool {
        if enabled {
            cards.insert(card)
            return true
        }
        if cards.contains(card) && cards.count == 1 { return false }
        cards.remove(card)
        glance.removeAll { $0 == card }
        if glance.isEmpty { glance = [Self.firstEnabled(in: cards)] }
        return true
    }

    public mutating func setSection(_ section: ProcessSection, enabled: Bool) {
        if enabled {
            sections.insert(section)
        } else {
            sections.remove(section)
        }
    }

    public mutating func setGlanceEnabled(_ enabled: Bool) {
        glanceEnabled = enabled
    }

    public mutating func setMenuIcon(_ icon: MenuIcon) {
        menuIcon = icon
    }

    public mutating func setTheme(_ theme: AppTheme) {
        self.theme = theme
    }

    /// Accepts only themes from the dark list. Returns false otherwise.
    @discardableResult
    public mutating func setSystemDarkTheme(_ theme: AppTheme) -> Bool {
        guard AppTheme.darkChoices.contains(theme) else { return false }
        systemDarkTheme = theme
        return true
    }

    /// Accepts only themes from the light list. Returns false otherwise.
    @discardableResult
    public mutating func setSystemLightTheme(_ theme: AppTheme) -> Bool {
        guard AppTheme.lightChoices.contains(theme) else { return false }
        systemLightTheme = theme
        return true
    }

    /// The theme to draw with. System resolves to the dark or light choice; every other theme is returned as is.
    public func resolvedTheme(isDark: Bool) -> AppTheme {
        guard theme == .system else { return theme }
        return isDark ? systemDarkTheme : systemLightTheme
    }

    /// The ON cards in the user's order.
    public var orderedCards: [Card] {
        cardOrder.filter { cards.contains($0) }
    }

    /// Moves a card one place up (negative offset) or down (positive). Returns false at either end.
    @discardableResult
    public mutating func moveCard(_ card: Card, by offset: Int) -> Bool {
        guard let index = cardOrder.firstIndex(of: card) else { return false }
        let target = index + offset
        guard cardOrder.indices.contains(target) else { return false }
        // Remove and re-insert, so cards between the two places shift by one. A swap would be wrong for offsets above 1.
        cardOrder.remove(at: index)
        cardOrder.insert(card, at: target)
        return true
    }

    /// Adds a card to, or removes it from, the glance selection. Adding needs an ON card and room under the limit.
    @discardableResult
    public mutating func toggleGlance(_ card: Card) -> Bool {
        if let index = glance.firstIndex(of: card) {
            guard glance.count > Self.glanceRange.lowerBound else { return false }
            glance.remove(at: index)
        } else {
            guard cards.contains(card), glance.count < Self.glanceRange.upperBound else { return false }
            glance.append(card)
        }
        return true
    }

    private static func firstEnabled(in cards: Set<Card>) -> Card {
        Card.allCases.first { cards.contains($0) } ?? .cpu
    }
}

// MARK: - Persistence

extension Preferences {
    private enum Key {
        static let cards = "topd.cards"
        static let sections = "topd.sections"
        static let glance = "topd.glance"
        static let glanceEnabled = "topd.glanceEnabled"
        static let menuIcon = "topd.menuIcon"
        static let cardOrder = "topd.cardOrder"
        static let theme = "topd.theme"
        static let systemDarkTheme = "topd.systemDarkTheme"
        static let systemLightTheme = "topd.systemLightTheme"
    }

    /// Missing or unreadable values fall back to defaults; the initializer normalizes anything odd.
    public init(defaults: UserDefaults) {
        let cards = defaults.stringArray(forKey: Key.cards)
            .map { Set($0.compactMap(Card.init(rawValue:))) } ?? Set(Card.allCases)
        let sections = defaults.stringArray(forKey: Key.sections)
            .map { Set($0.compactMap(ProcessSection.init(rawValue:))) } ?? Set(ProcessSection.allCases)
        let glance = defaults.stringArray(forKey: Key.glance)?.compactMap(Card.init(rawValue:)) ?? Preferences.defaultGlance
        let menuIcon = defaults.string(forKey: Key.menuIcon).flatMap(MenuIcon.init(rawValue:)) ?? .topd
        let cardOrder = defaults.stringArray(forKey: Key.cardOrder)?.compactMap(Card.init(rawValue:)) ?? Card.allCases
        let theme = defaults.string(forKey: Key.theme).flatMap(AppTheme.init(rawValue:)) ?? .glass
        let systemDark = defaults.string(forKey: Key.systemDarkTheme).flatMap(AppTheme.init(rawValue:)) ?? .dracula
        let systemLight = defaults.string(forKey: Key.systemLightTheme).flatMap(AppTheme.init(rawValue:)) ?? .gitHubLight
        self.init(
            cards: cards,
            sections: sections,
            glance: glance,
            glanceEnabled: defaults.bool(forKey: Key.glanceEnabled),
            menuIcon: menuIcon,
            cardOrder: cardOrder,
            theme: theme,
            systemDarkTheme: systemDark,
            systemLightTheme: systemLight
        )
    }

    public func save(to defaults: UserDefaults) {
        defaults.set(cards.map(\.rawValue).sorted(), forKey: Key.cards)
        defaults.set(sections.map(\.rawValue).sorted(), forKey: Key.sections)
        defaults.set(glance.map(\.rawValue), forKey: Key.glance)
        defaults.set(glanceEnabled, forKey: Key.glanceEnabled)
        defaults.set(menuIcon.rawValue, forKey: Key.menuIcon)
        defaults.set(cardOrder.map(\.rawValue), forKey: Key.cardOrder)
        defaults.set(theme.rawValue, forKey: Key.theme)
        defaults.set(systemDarkTheme.rawValue, forKey: Key.systemDarkTheme)
        defaults.set(systemLightTheme.rawValue, forKey: Key.systemLightTheme)
    }
}
