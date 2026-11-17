import Foundation
import Observation
import TopdCore

/// Holds the user's choices and persists every accepted change. Rule checks live in `Preferences`.
@Observable
final class SettingsModel {
    private(set) var preferences: Preferences
    private let defaults: UserDefaults

    /// Called after each accepted change, so the menu bar can redraw.
    @ObservationIgnored var onChange: (() -> Void)?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        preferences = Preferences(defaults: defaults)
    }

    @discardableResult
    func setCard(_ card: Card, enabled: Bool) -> Bool {
        apply { $0.setCard(card, enabled: enabled) }
    }

    func setSection(_ section: ProcessSection, enabled: Bool) {
        apply { $0.setSection(section, enabled: enabled); return true }
    }

    func setGlanceEnabled(_ enabled: Bool) {
        apply { $0.setGlanceEnabled(enabled); return true }
    }

    @discardableResult
    func toggleGlance(_ card: Card) -> Bool {
        apply { $0.toggleGlance(card) }
    }

    func setMenuIcon(_ icon: MenuIcon) {
        apply { $0.setMenuIcon(icon); return true }
    }

    func setTheme(_ theme: AppTheme) {
        apply { $0.setTheme(theme); return true }
    }

    @discardableResult
    func setSystemDarkTheme(_ theme: AppTheme) -> Bool {
        apply { $0.setSystemDarkTheme(theme) }
    }

    @discardableResult
    func setSystemLightTheme(_ theme: AppTheme) -> Bool {
        apply { $0.setSystemLightTheme(theme) }
    }

    @discardableResult
    func moveCard(_ card: Card, by offset: Int) -> Bool {
        apply { $0.moveCard(card, by: offset) }
    }

    @discardableResult
    private func apply(_ change: (inout Preferences) -> Bool) -> Bool {
        var next = preferences
        guard change(&next) else { return false }
        preferences = next
        preferences.save(to: defaults)
        onChange?()
        return true
    }
}
