import AppKit
import SwiftUI
import TopdCore

/// Owns the menu bar item. Left click opens the popover; right click opens a short menu.
final class StatusController: NSObject, NSPopoverDelegate {
    private let settings: SettingsModel
    private let monitor: Monitor
    private let launch: LaunchAtLogin
    private let popoverState = PopoverState()
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let popover = NSPopover()
    private let hosting: NSHostingController<PopoverRoot>
    /// Watches clicks anywhere on screen while the popover is open, so a click outside it closes it.
    private var outsideClickMonitor: Any?
    /// What the menu bar item last showed, so unchanged ticks skip redrawing it.
    private var menuBarKey: String?

    init(settings: SettingsModel, monitor: Monitor, launch: LaunchAtLogin) {
        self.settings = settings
        self.monitor = monitor
        self.launch = launch
        hosting = NSHostingController(rootView: PopoverRoot(settings: settings, monitor: monitor, launch: launch, state: popoverState))
        super.init()

        hosting.sizingOptions = [.preferredContentSize]
        popover.contentViewController = hosting
        popover.behavior = .transient
        popover.delegate = self

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        settings.onChange = { [weak self] in
            self?.refreshMenuBar()
            if self?.popover.isShown == true { self?.applyTheme() }
        }
        monitor.onUpdate = { [weak self] in self?.refreshMenuBar() }
        refreshMenuBar()
    }

    // MARK: - Theme

    /// Light themes draw the popover in light appearance, dark themes in dark, and the default and match-system follow the system.
    private func applyTheme() {
        popover.appearance = settings.preferences.theme.appearance
    }

    // MARK: - Menu bar item

    /// Icon only when at-a-glance is OFF; otherwise the chosen values. Both are fixed-width, so the item does not resize.
    private func refreshMenuBar() {
        let preferences = settings.preferences
        guard let button = statusItem.button else { return }
        // Redraw only when what the menu bar shows has changed. Ticks that change nothing cost no layout work.
        let key = preferences.glanceEnabled
            ? "glance|" + preferences.glance.map { "\($0.rawValue)=\($0.glanceText(monitor.snapshot))" }.joined(separator: ",")
            : "icon|\(preferences.menuIcon.rawValue)"
        guard key != menuBarKey else { return }
        menuBarKey = key
        if preferences.glanceEnabled {
            let image = MenuBarImage.glance(preferences.glance, snapshot: monitor.snapshot)
            button.image = image
            statusItem.length = image.size.width
        } else {
            button.image = preferences.menuIcon.menuBarImage
            statusItem.length = NSStatusItem.squareLength
        }
        button.imagePosition = .imageOnly
    }

    // MARK: - Clicks and popover

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showMenu()
        } else {
            togglePopover()
        }
    }

    private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            openPopover()
        }
    }

    private func openPopover() {
        guard let button = statusItem.button, !popover.isShown else { return }
        launch.refresh()
        // Set before showing: setting the appearance on a hidden popover made SwiftUI re-lay out while closed (this caused an idle CPU regression).
        applyTheme()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
        NSApp.activate(ignoringOtherApps: true)
        monitor.setPopoverVisible(true)
        startOutsideClickMonitor()
    }

    func popoverDidClose(_ notification: Notification) {
        stopOutsideClickMonitor()
        monitor.setPopoverVisible(false)
        popoverState.showsPreferences = false
    }

    // MARK: - Click outside

    private func startOutsideClickMonitor() {
        stopOutsideClickMonitor()
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.closeIfOutside()
        }
    }

    private func stopOutsideClickMonitor() {
        if let outsideClickMonitor {
            NSEvent.removeMonitor(outsideClickMonitor)
        }
        outsideClickMonitor = nil
    }

    /// Closes the popover for a click outside its window. A click on the menu bar icon is left to the icon, which toggles.
    private func closeIfOutside() {
        guard popover.isShown else { return }
        let point = NSEvent.mouseLocation
        if let window = popover.contentViewController?.view.window, window.frame.contains(point) {
            return
        }
        if let button = statusItem.button, let buttonWindow = button.window {
            let buttonFrame = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
            if buttonFrame.contains(point) { return }
        }
        popover.performClose(nil)
    }

    // MARK: - Right-click menu

    /// Built fresh on every right click, so every status read is current.
    private func showMenu() {
        launch.refresh()
        let menu = NSMenu()
        menu.addItem(item("Show topd", action: #selector(showMetrics)))
        menu.addItem(preferencesItem())
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit topd", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    private func preferencesItem() -> NSMenuItem {
        let root = NSMenuItem(title: "Preferences", action: nil, keyEquivalent: "")
        let menu = NSMenu(title: "Preferences")
        menu.addItem(submenuItem("General", generalMenu()))
        menu.addItem(submenuItem("At a glance", glanceMenu()))
        menu.addItem(submenuItem("Cards", cardsMenu()))
        menu.addItem(submenuItem("Processes", processMenu()))
        root.submenu = menu
        return root
    }

    private func cardsMenu() -> NSMenu {
        let preferences = settings.preferences
        let menu = NSMenu(title: "Cards")
        for card in Card.allCases {
            menu.addItem(item(card.title, state: preferences.cards.contains(card), action: #selector(toggleCard(_:)), value: card.rawValue))
        }
        return menu
    }

    private func processMenu() -> NSMenu {
        let preferences = settings.preferences
        let menu = NSMenu(title: "Processes")
        menu.addItem(item("Top 5 by CPU", state: preferences.sections.contains(.topCPU), action: #selector(toggleSection(_:)), value: ProcessSection.topCPU.rawValue))
        menu.addItem(item("Top 5 by memory", state: preferences.sections.contains(.topMemory), action: #selector(toggleSection(_:)), value: ProcessSection.topMemory.rawValue))
        return menu
    }

    private func glanceMenu() -> NSMenu {
        let preferences = settings.preferences
        let menu = NSMenu(title: "At a glance")
        menu.addItem(item("Show values in menu bar", state: preferences.glanceEnabled, action: #selector(toggleGlanceEnabled)))
        menu.addItem(.separator())
        for card in Card.allCases {
            let entry = item(card.title, state: preferences.glance.contains(card), action: #selector(toggleGlance(_:)), value: card.rawValue)
            entry.isEnabled = preferences.cards.contains(card)
            menu.addItem(entry)
        }
        return menu
    }

    private func generalMenu() -> NSMenu {
        let menu = NSMenu(title: "General")
        menu.addItem(item("Launch at login", state: launch.state == .enabled, action: #selector(toggleLaunchAtLogin)))
        if let message = launch.message {
            let line = NSMenuItem(title: message, action: nil, keyEquivalent: "")
            line.isEnabled = false
            menu.addItem(line)
        }
        return menu
    }

    private func submenuItem(_ title: String, _ menu: NSMenu) -> NSMenuItem {
        let entry = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        entry.submenu = menu
        return entry
    }

    private func item(_ title: String, state: Bool = false, action: Selector, value: String? = nil) -> NSMenuItem {
        let entry = NSMenuItem(title: title, action: action, keyEquivalent: "")
        entry.target = self
        entry.representedObject = value
        entry.state = state ? .on : .off
        return entry
    }

    @objc private func showMetrics() {
        popoverState.showsPreferences = false
        openPopover()
    }

    @objc private func toggleCard(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let card = Card(rawValue: raw) else { return }
        if !settings.setCard(card, enabled: !settings.preferences.cards.contains(card)) { NSSound.beep() }
    }

    @objc private func toggleSection(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let section = ProcessSection(rawValue: raw) else { return }
        settings.setSection(section, enabled: !settings.preferences.sections.contains(section))
    }

    @objc private func toggleGlanceEnabled() {
        settings.setGlanceEnabled(!settings.preferences.glanceEnabled)
    }

    @objc private func toggleGlance(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let card = Card(rawValue: raw) else { return }
        if !settings.toggleGlance(card) { NSSound.beep() }
    }

    @objc private func toggleLaunchAtLogin() {
        launch.setEnabled(launch.state != .enabled)
    }
}
